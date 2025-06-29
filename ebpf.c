// Docs: https://docs.ebpf.io/

// XXX: test incoming conns, check how to identify those
// XXX: re-add kprobes for wireguard tunnels
// XXX: test how tracepoints work with firewalled conns
// XXX: check packets on some skb-egress hook, mark in maps which ones get through

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

struct conn_map_key { u64 sk; u32 pid; } __attribute__((packed));
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


static __always_inline void conn_update(struct sock *sk, u16 proto, int bs) {
	// It'd be nice to use skc_cookie for ck key, but it's not pre-generated,
	//  and bpf_get_socket_cookie can only be triggered from fprobe,
	//  which require BTF and such fancier kernel debug data - more dependencies.
	// Using sk addr + pid should be enough, unless pid recycles sockets too fast,
	//  in which case it won't be useful to display its connections separately anyway.
	u64 ns = bpf_ktime_get_ns();
	u32 pid = bpf_get_current_pid_tgid() >> 32;
	struct conn_map_key ck = { .sk = (u64) sk, .pid = pid };

	struct conn_t *connp = bpf_map_lookup_elem(&conn_map, &ck);
	if (connp) { // pre-existing connection - update counters
		if (bs < 0) connp->rx += -bs; else connp->tx += bs;
		if (ns < (connp->ns_trx + CONN_TRX_UPD_NS)) return;
		connp->ns_trx = ns; }

	else { // new connection - gather socket/process info
		struct conn_t conn;
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
		conn.lport = bpf_htons(conn.lport);
		conn.rport = bpf_htons(conn.rport);
		conn.rx = 0; conn.tx = 0; conn.ns_trx = 0;
		if (bs < 0) conn.rx += -bs; else conn.tx += bs;
		bpf_get_current_comm(&conn.comm, sizeof(conn.comm));
		bpf_map_update_elem(&conn_map, &ck, &conn, BPF_ANY);
		connp = &conn; }

	struct conn_t *e = bpf_ringbuf_reserve(&updates, sizeof(struct conn_t), 0);
	if (e) {
		bpf_probe_read(e, sizeof(struct conn_t), connp);
		bpf_ringbuf_submit(e, 0); }
}


// See /sys/kernel/debug/tracing/events/sock/sock_send_length/format + recv
// recv(flags & 2) = MSG_PEEK, should be skipped for byte-counting purposes
struct sock_data_ctx {
	unsigned short _type; unsigned char _flags; unsigned char _prt; int _pid;
	struct sock *sk; u16 family; u16 protocol; int ret; int flags;
};

SEC("tracepoint/sock/sock_send_length")
int tp__sock_send(struct sock_data_ctx *ctx) {
	if ( !(ctx->family == AF_INET || ctx->family == AF_INET6)
		// XXX: add more protocols
		|| !(ctx->protocol == IPPROTO_TCP || ctx->protocol == IPPROTO_UDP) ) return 0;
	conn_update(ctx->sk, ctx->protocol, ctx->ret > 0 ? ctx->ret : 0);
	return 0;
}

SEC("tracepoint/sock/sock_recv_length")
int tp__sock_recv(struct sock_data_ctx *ctx) {
	if ( !(ctx->family == AF_INET || ctx->family == AF_INET6)
		// XXX: add more protocols
		|| !(ctx->protocol == IPPROTO_TCP || ctx->protocol == IPPROTO_UDP) ) return 0;
	conn_update( ctx->sk, ctx->protocol,
		((ctx->flags & MSG_PEEK) == 0 && ctx->ret > 0) ? -ctx->ret : 0 );
	return 0;
}


char _license[] SEC("license") = "GPL";
u32 _version SEC("version") = LINUX_VERSION_CODE;
