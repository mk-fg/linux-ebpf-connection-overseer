// Docs: https://docs.ebpf.io/

// XXX: copy inet_dgram_connect and iptunnel_xmit probes from opensnitch
// XXX: iptunnel_xmit seem to be only for ipv4 tunnels - extend to ipv6
// XXX: test how connect-returns work with firewalled conns
// XXX: check packets on some skb-egress hook, mark in maps which ones get through
// XXX: add cgroup id's to maps
// XXX: resolve cgroup ids to names, if possible here

#define KBUILD_MODNAME "leco"

#include <linux/version.h>
#include <linux/sched.h>
#include <linux/ptrace.h>
#include <uapi/linux/bpf.h>
#include <uapi/linux/tcp.h>
#include <net/sock.h>
#include <net/udp_tunnel.h>
#include <net/inet_sock.h>

#include "build/bpf/bpf_helpers.h"
#include "build/bpf/bpf_tracing.h"


// eBPF array is used as a readable ring-buffer to keep last conn
//  info between userspace restarts, and only read on startup there.
// Actual ring-buffer is to poll for new connections to display after that.

#define CONN_TABLE_SIZE 1000
__u32 conn_idx = 0; // wraps around table size

enum conn_type {CT_TCP4 = 1, CT_TCP6, CT_UDP4, CT_UDP6};

struct conn_t { // ~70B
	u8 ct;
	u64 ns; // CLOCK_MONOTONIC
	u128 saddr;
	u128 daddr;
	u16 sport;
	u16 dport;
	u32 pid;
	u32 uid;
	char comm[TASK_COMM_LEN];
} __attribute__((packed));

struct {
	__uint(type, BPF_MAP_TYPE_ARRAY);
	__type(key, unsigned int);
	__type(value, struct conn_t);
	__uint(max_entries, CONN_TABLE_SIZE);
} conn_table SEC(".maps");

struct {
	__uint(type, BPF_MAP_TYPE_RINGBUF);
	__uint(max_entries, 2 * 4096); // ~100 conn_t events
} updates SEC(".maps");


// TCP IP-tuple can be copied from "struct sock" only upon
//  return from tcp_connect(), so socket pointers are stashed here.
struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__type(key, u64);
	__type(value, u64);
	__uint(max_entries, 300);
} cache_tcp SEC(".maps");

// cache_udp deduplicates repeated UDP sendmsg packets to same destination.
// First sendmsg should bind socket, so saddr/sport are redundant with sk pointer.
struct cache_udp_key {
	u64 sk;
	u128 daddr;
	u16 dport;
} __attribute__((packed));

struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__type(key, struct cache_udp_key);
	__type(value, u64);
	__uint(max_entries, 300);
} cache_udp SEC(".maps");


static __always_inline void conn_push(u64 pid_tgid, struct conn_t conn) {
	conn.ns = bpf_ktime_get_ns();
	conn.dport = (conn.dport>>8) | (conn.dport<<8); // skc_dport be16 -> u16
	conn.pid = pid_tgid >> 32;
	conn.uid = bpf_get_current_uid_gid() & 0xffffffff;
	bpf_get_current_comm(&conn.comm, sizeof(conn.comm));
	bpf_map_update_elem(&conn_table, &conn_idx, &conn, BPF_ANY);
	conn_idx = (conn_idx + 1) % CONN_TABLE_SIZE;
	struct conn_t *e = bpf_ringbuf_reserve(&updates, sizeof(struct conn_t), 0);
	if (e) {
		bpf_probe_read(e, sizeof(struct conn_t), &conn);
		bpf_ringbuf_submit(e, 0); }
}


SEC("kprobe/tcp_v4_connect")
int kprobe__tcp_v4_connect(struct pt_regs *ctx) {
	struct sock *sk = (struct sock *) PT_REGS_PARM1(ctx);
	u64 pid_tgid = bpf_get_current_pid_tgid();
	bpf_map_update_elem(&cache_tcp, &pid_tgid, &sk, BPF_ANY);
	return 0;
};

SEC("kretprobe/tcp_v4_connect")
int kretprobe__tcp_v4_connect(struct pt_regs *ctx) {
	u64 pid_tgid = bpf_get_current_pid_tgid();
	struct sock **skp = bpf_map_lookup_elem(&cache_tcp, &pid_tgid);
	if (!skp) return 0;
	struct conn_t conn = {.ct = CT_TCP4}; struct sock *sk = *skp;
	bpf_probe_read(&conn.sport, 2, &sk->__sk_common.skc_num);
	bpf_probe_read(&conn.dport, 2, &sk->__sk_common.skc_dport);
	bpf_probe_read(&conn.saddr, 4, &sk->__sk_common.skc_rcv_saddr);
	bpf_probe_read(&conn.daddr, 4, &sk->__sk_common.skc_daddr);
	conn_push(pid_tgid, conn);
	bpf_map_delete_elem(&cache_tcp, &pid_tgid);
	return 0;
};

SEC("kprobe/tcp_v6_connect")
int kprobe__tcp_v6_connect(struct pt_regs *ctx) {
	struct sock *sk = (struct sock *)PT_REGS_PARM1(ctx);
	u64 pid_tgid = bpf_get_current_pid_tgid();
	bpf_map_update_elem(&cache_tcp, &pid_tgid, &sk, BPF_ANY);
	return 0;
};

SEC("kretprobe/tcp_v6_connect")
int kretprobe__tcp_v6_connect(struct pt_regs *ctx) {
	u64 pid_tgid = bpf_get_current_pid_tgid();
	struct sock **skp = bpf_map_lookup_elem(&cache_tcp, &pid_tgid);
	if (!skp) return 0;
	struct conn_t conn = {.ct = CT_TCP6}; struct sock *sk = *skp;
	bpf_probe_read(&conn.sport, 2, &sk->__sk_common.skc_num);
	bpf_probe_read(&conn.dport, 2, &sk->__sk_common.skc_dport);
	bpf_probe_read(&conn.saddr, 16, &sk->__sk_common.skc_v6_rcv_saddr);
	bpf_probe_read(&conn.daddr, 16, &sk->__sk_common.skc_v6_daddr);
	conn_push(pid_tgid, conn);
	bpf_map_delete_elem(&cache_tcp, &pid_tgid);
	return 0;
};


SEC("kprobe/udp_sendmsg")
int kprobe__udp_sendmsg(struct pt_regs *ctx) {
	u64 pid_tgid = bpf_get_current_pid_tgid();
	struct sock *sk = (struct sock *) PT_REGS_PARM1(ctx);
	struct msghdr *msg = (struct msghdr *) PT_REGS_PARM2(ctx);
	struct conn_t conn = {.ct = CT_UDP4};

	bpf_probe_read(&conn.dport, 2, &sk->__sk_common.skc_dport);
	if (conn.dport) bpf_probe_read(&conn.daddr, 4, &sk->__sk_common.skc_daddr);
	else { // dunno if this fallback is necessary
		struct sockaddr_in *usin;
		bpf_probe_read(&usin, sizeof(struct sockaddr_in *), &msg->msg_name);
		bpf_probe_read(&conn.dport, 2, &usin->sin_port);
		bpf_probe_read(&conn.daddr, 4, &usin->sin_addr.s_addr); }

	struct cache_udp_key ck = { // deduplicate same sk-dst sendmsg
		.sk = (u64) sk, .daddr = conn.daddr, .dport = conn.dport };
	u64 *pid_tgid_ck = bpf_map_lookup_elem(&cache_udp, &ck);
	if (pid_tgid_ck && *pid_tgid_ck == pid_tgid) return 0;
	bpf_map_update_elem(&cache_udp, &ck, &pid_tgid, BPF_ANY);

	bpf_probe_read(&conn.sport, 2, &sk->__sk_common.skc_num);
	conn.saddr = 0; // make sure remaining 12B are unset as well
	bpf_probe_read(&conn.saddr, 4, &sk->__sk_common.skc_rcv_saddr);
	if (!conn.saddr) {
		u64 cmsg;
		bpf_probe_read(&cmsg, sizeof(cmsg), &msg->msg_control);
		struct in_pktinfo *inpkt = (struct in_pktinfo *) CMSG_DATA(cmsg);
		bpf_probe_read(&conn.saddr, 4, &inpkt->ipi_spec_dst.s_addr); }

	conn_push(pid_tgid, conn);
	return 0;
};

SEC("kprobe/udpv6_sendmsg")
int kprobe__udpv6_sendmsg(struct pt_regs *ctx) {
	u64 pid_tgid = bpf_get_current_pid_tgid();
	struct sock *sk = (struct sock *) PT_REGS_PARM1(ctx);
	struct msghdr *msg = (struct msghdr *) PT_REGS_PARM2(ctx);
	struct conn_t conn = {.ct = CT_UDP6};

	bpf_probe_read(&conn.dport, 2, &sk->__sk_common.skc_dport);
	if (conn.dport) bpf_probe_read(&conn.daddr, 16, &sk->__sk_common.skc_v6_daddr);
	else { // dunno if this fallback is necessary
		struct sockaddr_in6 *usin;
		bpf_probe_read(&usin, sizeof(struct sockaddr_in *), &msg->msg_name);
		bpf_probe_read(&conn.dport, 2, &usin->sin6_port);
		bpf_probe_read(&conn.daddr, 16, &usin->sin6_addr.s6_addr); }

	struct cache_udp_key ck = { // deduplicate same sk-dst sendmsg
		.sk = (u64) sk, .daddr = conn.daddr, .dport = conn.dport };
	u64 *pid_tgid_ck = bpf_map_lookup_elem(&cache_udp, &ck);
	if (pid_tgid_ck && *pid_tgid_ck == pid_tgid) return 0;
	bpf_map_update_elem(&cache_udp, &ck, &pid_tgid, BPF_ANY);

	bpf_probe_read(&conn.sport, 2, &sk->__sk_common.skc_num);
	bpf_probe_read(&conn.saddr, 16, &sk->__sk_common.skc_v6_rcv_saddr);
	if (!conn.saddr) {
		u64 cmsg;
		bpf_probe_read(&cmsg, sizeof(cmsg), &msg->msg_control);
		struct in6_pktinfo *inpkt = (struct in6_pktinfo *) CMSG_DATA(cmsg);
		bpf_probe_read(&conn.saddr, 16, &inpkt->ipi6_addr.s6_addr); }

	conn_push(pid_tgid, conn);
	return 0;
};


char _license[] SEC("license") = "GPL";
u32 _version SEC("version") = LINUX_VERSION_CODE;
