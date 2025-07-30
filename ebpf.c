// Docs: https://docs.ebpf.io/

// sock_send / sock_recv tracepoints used here ignore firewall rules, e.g. script
//  doing send() to nftables-blocked remote or on closed socket will still trigger those.

#define KBUILD_MODNAME "leco"

#include <linux/version.h>
#include <net/sock.h>

#include "build/bpf/bpf_helpers.h"
#include "build/bpf/bpf_tracing.h"
#include "build/bpf/bpf_endian.h"


// Macro to make large int literals more readable, as --std=c23 doesn't work for eBPF atm
#define NS(...) NS_(__VA_ARGS__, , , , , , , , , , )
#define NS_(a1_, a2_, a3_, a4_, a5_, a6_, a7_, a8_, ...) a1_##a2_##a3_##a4_##a5_##a6_##a7_##a8_

// eBPF array is used as a readable ring-buffer to keep last conn
//  info between userspace restarts, and only read on startup there.
// Actual ring-buffer is to poll for new connections to display after that.

// Double-underscore-prefixed types are from userspace API headers
// To check global counters: bpftool map dump pinned /sys/fs/bpf/leco/maps/ebpf_bss
__u64 conn_proc_errs = 0;

#define CONN_TRX_UPD_NS NS(3,000,000,000) // rate-limit for trx-counter update events

enum conn_type { CT_TCP4 = 1, CT_TCP6, CT_UDP4, CT_UDP6, CT_X4, CT_X6 };

struct conn_t { // ~93B
	u8 ct; u64 ns; // CLOCK_MONOTONIC
	u128 laddr; u128 raddr; u16 lport; u16 rport; // local/remote addr/port
	u32 pid; u32 uid; char comm[TASK_COMM_LEN];
	u64 ns_trx; u64 rx; u64 tx; u64 cg;
} __attribute__((packed));

struct conn_map_key { // has ports to avoid clashes on sk addr reuse
	u64 sk; u32 pid; u32 ports;
} __attribute__((packed));

struct {
	__uint(type, BPF_MAP_TYPE_LRU_HASH);
	__type(key, struct conn_map_key);
	__type(value, struct conn_t);
	__uint(max_entries, 1000);
} conn_map SEC(".maps");

struct {
	__uint(type, BPF_MAP_TYPE_RINGBUF);
	__uint(max_entries, 6144); // ~50 conn_t events
} updates SEC(".maps");


static __always_inline bool conn_update_msg_ep(
		struct conn_t *connp, struct sock *sk, struct msghdr *msg ) {
	// Sets destination address/port from msghdr in unconnected sendmsg syscalls
	// Source addr/port still comes from socket and shouldn't change
	if (!msg || !connp) return false;
	bool ipv4 = connp->ct == CT_TCP4 || connp->ct == CT_UDP4 || connp->ct == CT_X4;
	u16 port; u128 addr;
	bpf_probe_read(&port, 2, &sk->__sk_common.skc_dport); // in case sk was connected later
	if (port) {
		if (ipv4) bpf_probe_read(&addr, 4, &sk->__sk_common.skc_daddr);
		else bpf_probe_read(&addr, 16, &sk->__sk_common.skc_v6_daddr); }
	else { // sendmsg shouldn't update addr/port on sk
		if (ipv4) {
			struct sockaddr_in *usin;
			bpf_probe_read(&usin, sizeof(struct sockaddr_in *), &msg->msg_name);
			bpf_probe_read(&port, 2, &usin->sin_port);
			bpf_probe_read(&addr, 4, &usin->sin_addr.s_addr); }
		else {
			struct sockaddr_in6 *usin6;
			bpf_probe_read(&usin6, sizeof(struct sockaddr_in6 *), &msg->msg_name);
			bpf_probe_read(&port, 2, &usin6->sin6_port);
			bpf_probe_read(&addr, 16, &usin6->sin6_addr.s6_addr); } }
	if (!port) return false;
	port = bpf_htons(port);
	if (addr == connp->raddr && port == connp->rport) return false;
	connp->raddr = addr; connp->rport = port; return true;
}

static __always_inline void conn_update(
		struct sock *sk, u16 proto, int bs, struct msghdr *msg) {
	// It's difficult to use dynamic memory and pointers with eBPF checker,
	//  hence one big func with goto's, to match underlying assembly structure.

	// It'd be nice to use skc_cookie for ck key, but it's not pre-generated,
	//  and bpf_get_socket_cookie can only be triggered from fprobe,
	//  which require BTF and such fancier kernel debug data - more dependencies.
	// Using sk addr + misc chaff should hopefully be unique enough for this tool.
	u64 ns = bpf_ktime_get_ns();
	u32 pid = bpf_get_current_pid_tgid() >> 32;
	struct conn_map_key ck = { .sk = (u64) sk, .pid = pid };
	bpf_probe_read(&ck.ports, 4, &sk->__sk_common.skc_portpair);

	struct conn_t *connrb, *connp = bpf_map_lookup_elem(&conn_map, &ck);
	if (connp) { // pre-existing connection - update counters
		if (bs < 0) connp->rx += -bs; else connp->tx += bs;
		if (conn_update_msg_ep(connp, sk, msg)) goto rb_update;
		if (ns < (connp->ns_trx + CONN_TRX_UPD_NS)) return; // rate-limits ringbuf updates
		connp->ns_trx = ns; goto rb_update; }

	struct conn_t conn; // new connection - gather socket/process info
	struct sock_common *s = &sk->__sk_common;
	unsigned short af;
	bpf_probe_read(&af, 2, &s->skc_family);
	// AF should be filtered by tracepoint arg, so mismatch here means bogus sk
	if (af != AF_INET && af != AF_INET6) { conn_proc_errs++; return; }
	conn.ct =
		proto == IPPROTO_TCP ? (af == AF_INET ? CT_TCP4 : CT_TCP6) :
		proto == IPPROTO_UDP ? (af == AF_INET ? CT_UDP4 : CT_UDP6) :
		af == AF_INET ? CT_X4 : CT_X6 ;
	conn.ns = ns;
	conn.pid = pid;
	conn.uid = bpf_get_current_uid_gid() & 0xffffffff;
	conn.cg = bpf_get_current_cgroup_id();
	if (af == AF_INET) {
		bpf_probe_read(&conn.laddr, 4, &s->skc_rcv_saddr);
		bpf_probe_read(&conn.raddr, 4, &s->skc_daddr); }
	else {
		bpf_probe_read(&conn.laddr, 16, &s->skc_v6_rcv_saddr);
		bpf_probe_read(&conn.raddr, 16, &s->skc_v6_daddr); }
	bpf_probe_read(&conn.lport, 2, &s->skc_num);
	bpf_probe_read(&conn.rport, 2, &s->skc_dport);
	if (conn.rport) conn.rport = bpf_htons(conn.rport); // note: sport skc_num doesn't need this
	else conn_update_msg_ep(&conn, sk, msg);
	conn.rx = 0; conn.tx = 0; conn.ns_trx = ns;
	if (bs < 0) conn.rx += -bs; else conn.tx += bs;
	bpf_get_current_comm(&conn.comm, sizeof(conn.comm));
	bpf_map_update_elem(&conn_map, &ck, &conn, BPF_ANY);
	connp = &conn;

	rb_update:
	connrb = bpf_ringbuf_reserve(&updates, sizeof(struct conn_t), 0);
	if (!connrb) { conn_proc_errs++; return; }
	bpf_probe_read(connrb, sizeof(struct conn_t), connp);
	bpf_ringbuf_submit(connrb, 0);
}


// See /sys/kernel/debug/tracing/events/sock/sock_send_length/format + recv
// recv(flags & 2) = MSG_PEEK, should be skipped for byte-counting purposes
struct sock_data_ctx {
	unsigned short _type; unsigned char _flags; unsigned char _prt; int _pid;
	struct sock *sk; u16 family; u16 protocol; int ret; int flags;
};

SEC("tracepoint/sock/sock_send_length")
int tp__sock_send(struct sock_data_ctx *ctx) {
	if (!(ctx->family == AF_INET || ctx->family == AF_INET6)) return 0;
	conn_update(ctx->sk, ctx->protocol, ctx->ret > 0 ? ctx->ret : 0, NULL);
	return 0;
}

SEC("tracepoint/sock/sock_recv_length")
int tp__sock_recv(struct sock_data_ctx *ctx) {
	if (!(ctx->family == AF_INET || ctx->family == AF_INET6)) return 0;
	conn_update( ctx->sk, ctx->protocol,
		((ctx->flags & MSG_PEEK) == 0 && ctx->ret > 0) ? -ctx->ret : 0, NULL );
	return 0;
}

// XXX: use shared security_socket_sendmsg or something instead of these
SEC("kprobe/udp_sendmsg")
int kprobe__udp_sendmsg(struct pt_regs *ctx) {
	struct sock *sk = (struct sock *) PT_REGS_PARM1(ctx);
	struct msghdr *msg = (struct msghdr *) PT_REGS_PARM2(ctx);
	conn_update(sk, IPPROTO_UDP, 0, msg);
	return 0;
}

SEC("kprobe/udpv6_sendmsg")
int kprobe__udpv6_sendmsg(struct pt_regs *ctx) {
	struct sock *sk = (struct sock *) PT_REGS_PARM1(ctx);
	struct msghdr *msg = (struct msghdr *) PT_REGS_PARM2(ctx);
	conn_update(sk, IPPROTO_UDP, 0, msg);
	return 0;
}


char _license[] SEC("license") = "GPL";
u32 _version SEC("version") = LINUX_VERSION_CODE;
