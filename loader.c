#include <stdio.h>
#include <unistd.h>
#include <getopt.h>

#include <bpf/bpf.h>
#include <bpf/libbpf.h>
#include <systemd/sd-daemon.h>

#include "build/ebpf.skel.h"


int verbose = 0;

#define fd_version 1
#define fd_version_check "tcpv4_map_v1"

#define P(fmt, arg...) if (verbose) { \
	fprintf(stderr, "loader: " fmt "\n", ##arg); fflush(stderr); }
#define E(err, fmt, arg...) do { \
	fprintf(stderr, "ERROR: " fmt "\n", ##arg); fflush(stderr); \
	if (err) exit(err); } while (0)

static int libbpf_print_fn(enum libbpf_print_level level, const char *format, va_list args) {
	return vfprintf(stderr, format, args);
}


void parse_opts_usage(char *cmd, int err) {
	FILE *dst = !err ? stdout : stderr;
	fprintf( dst,
"Usage: %s [-h|--help] [-v|--verbose] [-t|--test]\n\n"
"Loads bundled network-monitoring eBPF programs, sets up maps for them,\n"
"  and stores all file descriptors to those in systemd File Descriptor Store.\n"
"Intended to be run from ExecStartPre=+... line in a systemd service file\n"
"  (which also has Type=notify NotifyAccess=exec and FileDescriptorStoreMax=16),\n"
"  to setup eBPF monitoring with data maps for main ExecStart= command in fdstore.\n"
"Detects running under systemd via sd_notify environment variables.\n"
"If eBPFs/maps are already setup/stored with systemd, exits without doing anything.\n"
"Exits with error if not running under systemd (unless -t/--test is used).\n\n"
"  -v/--verbose - enable verbose logging about systemd and libbpf interactions to stderr.\n"
"  -t/--test - run eBPF without systemd indefinitely, e.g. to check maps via bpftool.\n"
"\n", cmd );
	exit(err); }

void parse_opts(int argc, char *argv[], int *opt_verbose, int *opt_test) {
	extern char *optarg;
	extern int optind, opterr, optopt;
	int ch;
	static struct option opt_list[] = {
		{"help", no_argument, NULL, 1},
		{"verbose", no_argument, NULL, 2},
		{"test", no_argument, NULL, 3} };
	while ((ch = getopt_long(argc, argv, ":hvt", opt_list, NULL)) != -1) switch (ch) {
		case 'h': case 1: parse_opts_usage(argv[0], 0);;
		case 'v': case 2: *opt_verbose = true; break;
		case 't': case 3: *opt_test = true; break;
		case '?': E(0, "unrecognized option [ %s ]\n", argv[optind-1]); parse_opts_usage(argv[0], 1);
		case ':':
			if (optopt >= 32) E(0, "missing argument for -%c\n", optopt);
			else E(0, "missing argument for --%s\n", opt_list[optopt-1].name);
			parse_opts_usage(argv[0], 1);
		default: parse_opts_usage(argv[0], 1); }
	if (optind < argc) {
		E(0, "unrecognized argument value [ %s ]\n", argv[optind]);
		parse_opts_usage(argv[0], 1); }
}


int main(int argc, char **argv) {
	int opt_test = 0;
	parse_opts(argc, argv, &verbose, &opt_test);

	int n, err_exit = 1;

	// Check if eBPF is already loaded
	char **fd_names;
	int fd_n = opt_test ? 0 : sd_listen_fds_with_names(false, &fd_names);
	if (fd_n < 0) E(1, "sd_listen_fds check failed");
	for (n = 0; n < fd_n; n++)
		if (!strcmp(fd_names[n], fd_version_check)) break;
	if (n < fd_n) {
		if (sd_notify(false, "READY=1") <= 0) E(1, "sd_notify failed with fdstore");
		return 0; }
	else if (fd_n > 0) {
		P("sd_listen_fds version mismatch, re-initializing eBPF");
		for (n = 0; n < fd_n; n++) close(SD_LISTEN_FDS_START + n); }

	// Init/load/attach eBPF and maps
	libbpf_set_strict_mode(LIBBPF_STRICT_ALL);
	if (verbose) libbpf_set_print(libbpf_print_fn);
	struct ebpf *skel = ebpf__open_and_load();
	if (!skel) E(1, "Failed to open eBPF skeleton");
	if (ebpf__attach(skel)) { E(0, "Failed to attach eBPF skeleton"); goto err_cleanup; }

	// Store file descriptors with systemd
	int err = opt_test ? 0 : sd_notify(false, "READY=1");
	if (err < 0) E(1, "sd_notify failed");
	else if (!err) {
		if (!opt_test) E(1, "sd_notify failed to detect systemd environment");
		// XXX: add option to pin progs/maps instead
		P("Running in test-mode until stopped by signal");
		sleep(2147483647); err_exit = 0; goto err_cleanup; }

	// XXX: either pin or fd-pin progs, they get removed otherwise
	n = 0; int map_fd; const char *map_name;
	struct bpf_map *map = bpf_object__next_map(skel->obj, NULL);
	while (true) {
		if (!(map = bpf_object__next_map(skel->obj, map))) break;
		n++; map_name = bpf_map__name(map); map_fd = bpf_map__fd(map);
		P("storing fd #%d %d for map [ %s ]", n, map_fd, map_name);
		if (sd_pid_notifyf_with_fds( 0, false, &map_fd, 1,
				"FDSTORE=1\nFDPOLL=0\nFDNAME=%s_v%d", map_name, fd_version ) <= 0) {
			E(0, "sd_notify fdstore failed for map #%d [ %s ]", n, map_name); goto err_cleanup; } }
	P("Successfully loaded eBPF and stored all maps with systemd"); return 0;

	err_cleanup: ebpf__destroy(skel); return err_exit;
}
