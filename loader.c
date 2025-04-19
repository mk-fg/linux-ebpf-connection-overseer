#include <stdio.h>
#include <bpf/libbpf.h>

#include "build/ebpf.skel.h"

int tcpv4_map_fd, udpv4_map_fd, tcpv4_sock_map_fd,
	tcpv6_map_fd, udpv6_map_fd, tcpv6_sock_map_fd, icmp_sock_map_fd;

static int libbpf_print_fn(enum libbpf_print_level level, const char *format, va_list args) {
	return vfprintf(stderr, format, args);
}

int main(int argc, char **argv) {
	// XXX: check fdstore, exit if all fds are there already and version matches

	libbpf_set_strict_mode(LIBBPF_STRICT_ALL);
	libbpf_set_print(libbpf_print_fn); // XXX: only with some verbose/debug option

	struct ebpf *skel = ebpf__open_and_load();
	if (!skel) { fprintf(stderr, "ERROR: Failed to open BPF skeleton\n"); return 1; }

	tcpv4_map_fd = bpf_object__find_map_fd_by_name(skel->obj, "tcpv4_map");
	tcpv6_map_fd = bpf_object__find_map_fd_by_name(skel->obj, "tcpv6_map");
	udpv4_map_fd = bpf_object__find_map_fd_by_name(skel->obj, "udpv4_map");
	udpv6_map_fd = bpf_object__find_map_fd_by_name(skel->obj, "udpv6_map");
	tcpv4_sock_map_fd = bpf_object__find_map_fd_by_name(skel->obj, "tcpv4_sock");
	tcpv6_sock_map_fd = bpf_object__find_map_fd_by_name(skel->obj, "tcpv6_sock");
	icmp_sock_map_fd = bpf_object__find_map_fd_by_name(skel->obj, "icmp_sock");

	int err = ebpf__attach(skel);
	if (err) {
		fprintf(stderr, "ERROR: Failed to attach BPF skeleton\n");
		ebpf__destroy(skel);
		return 1;
	}

	fprintf(stderr, "XXX: add systemd fdstore stuff here\n");

	ebpf__destroy(skel);
}
