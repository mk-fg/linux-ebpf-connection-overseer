#include <stdio.h>
#include <unistd.h>
#include <getopt.h>

#include <bpf/bpf.h>
#include <bpf/libbpf.h>
#include <systemd/sd-daemon.h>

#include "build/ebpf.skel.h"


#define fd_version 1
#define fd_version_check "tcpv4_map_v1"

#define P(fmt, arg...) do { if (opt_verbose) { \
	fprintf(stderr, "loader: " fmt "\n", ##arg); fflush(stderr); } } while (0)
#define E(err, fmt, arg...) do { \
	fprintf(stderr, "ERROR: " fmt "\n", ##arg); fflush(stderr); \
	if (err) exit(err); } while (0)
#define EC(fmt, arg...) do { E(0, fmt, ##arg); goto err_cleanup; } while (0)

static int libbpf_print_fn(enum libbpf_print_level level, const char *format, va_list args) {
	return vfprintf(stderr, format, args);
}


void parse_opts_usage(int err, char *cmd) {
	FILE *dst = !err ? stdout : stderr;
	fprintf( dst,
"Usage: %s [-h|--help] [-v|--verbose] [-p/--pin <path>] [-t|--test]\n\n"
"Loads bundled network-monitoring eBPF programs, sets up maps for them,\n"
"  and stores all file descriptors to those in systemd File Descriptor Store.\n"
"Intended to be run from ExecStartPre=+... line in a systemd service file\n"
"  (which also has Type=notify NotifyAccess=exec and FileDescriptorStoreMax=32),\n"
"  to setup eBPF monitoring with data maps for main ExecStart= command in fdstore.\n"
"Detects running under systemd via sd_notify environment variables.\n"
"If eBPF objects are already setup/stored with systemd, exits without doing anything.\n"
"Exits with error if not running under systemd (unless -t/--test is used).\n\n"
"  -v/--verbose - enable verbose logging about systemd and libbpf interactions to stderr.\n"
"  -p/--pin <path> - pin eBPF progs/maps/links in dir on bpffs. Example: /sys/fs/bpf/leco\n"
"  -t/--test - pin/exit or run without systemd indefinitely, e.g. to check maps via bpftool.\n"
"\n", cmd );
	exit(err); }
#define usage(err) parse_opts_usage(err, argv[0]);

void parse_opts(int argc, char *argv[], int *opt_verbose, int *opt_test, char **opt_pin) {
	extern char *optarg; extern int optind, opterr, optopt; int ch;
	static struct option opt_list[] = {
		{"help", no_argument, NULL, 1},
		{"verbose", no_argument, NULL, 2},
		{"test", no_argument, NULL, 3},
		{"pin", required_argument, NULL, 4} };
	while ((ch = getopt_long(argc, argv, ":hvtp:", opt_list, NULL)) != -1) switch (ch) {
		case 'h': case 1: usage(0);
		case 'v': case 2: *opt_verbose = true; break;
		case 't': case 3: *opt_test = true; break;
		case 'p': case 4: *opt_pin = optarg; break;
		case '?': E(0, "unrecognized option [ %s ]\n", argv[optind-1]); usage(1);
		case ':':
			if (optopt >= 32) E(0, "missing argument for -%c\n", optopt);
			else E(0, "missing argument for --%s\n", opt_list[optopt-1].name);
			usage(1);
		default: usage(1); }
	if (optind < argc) {
		E(0, "unrecognized argument value [ %s ]\n", argv[optind]); usage(1); }
}


int main(int argc, char **argv) {
	int opt_verbose = false, opt_test = false;
	char *opt_pin = ""; char opt_pin_maps[512], opt_pin_links[512];
	parse_opts(argc, argv, &opt_verbose, &opt_test, &opt_pin);
	if (strlen(opt_pin)) {
		snprintf(opt_pin_maps, sizeof(opt_pin_maps), "%s/maps", opt_pin);
		snprintf(opt_pin_links, sizeof(opt_pin_links), "%s/links", opt_pin); }
	int n, err_exit = 1;

	// Check if eBPFs are already loaded
	char **fd_names;
	int fd_n = opt_test ? 0 : sd_listen_fds_with_names(false, &fd_names);
	if (fd_n < 0) E(1, "sd_listen_fds check failed");
	for (n = 0; n < fd_n; n++)
		if (!strcmp(fd_names[n], fd_version_check)) break;
	if (n < fd_n) { P("sd_listen_fds appears to be all-good, exiting"); return 0; }
	else if (fd_n > 0) {
		P("sd_listen_fds version mismatch, re-initializing eBPFs");
		for (n = 0; n < fd_n; n++)
			if (sd_notifyf( false, "FDSTOREREMOVE=1\nFDNAME=%s",
					fd_names[n] ) <= 0 || close(SD_LISTEN_FDS_START + n))
				E(1, "sd_listen_fds fd-cleanup failed [ %s ]", fd_names[n]); }

	// Init/load/attach eBPFs and maps
	libbpf_set_strict_mode(LIBBPF_STRICT_ALL);
	if (opt_verbose) libbpf_set_print(libbpf_print_fn);
	struct ebpf *skel = ebpf__open_and_load();
	if (!skel) E(1, "Failed to open eBPF skeleton");
	if (strlen(opt_pin)) {
		if ( !bpf_object__pin_programs(skel->obj, opt_pin)
				&& !bpf_object__pin_maps(skel->obj, opt_pin_maps) )
			P("Pinned eBPF programs/maps to [ %s ]", opt_pin);
		else EC("Failed to pin eBPF progs/maps to [ %s ]", opt_pin); }

	// Store file descriptors with systemd - prog attachment links and maps
	n = 0; int fd; const char *name;
	struct bpf_program *prog; struct bpf_link *link; char link_pin[512];
	bpf_object__for_each_program(prog, skel->obj) {
		n++; name = bpf_program__name(prog);
		if (!(link = bpf_program__attach(prog)))
			EC("Failed to attach program #%d [ %s ]", n, name);
		if (strlen(opt_pin) && ( snprintf( link_pin, 512, "%s/%s",
				opt_pin_links, name ) <= 0 || bpf_link__pin(link, link_pin) ))
			EC("Failed to pin prog-link #%d [ %s ] to [ %s ]", n, name, link_pin);
		if (opt_test) continue;
		fd = bpf_link__fd(link); // link-fd should keep program around as well
		P("Storing program-link fd #%d %d [ %s ]", n, fd, name);
		if (sd_pid_notifyf_with_fds( 0, false, &fd, 1,
				"FDSTORE=1\nFDPOLL=0\nFDNAME=%s_v%d_link", name, fd_version ) <= 0) {
			EC("sd_notify fdstore failed for prog-link #%d [ %s ]", n, name); } }
	struct bpf_map *map;
	bpf_object__for_each_map(map, skel->obj) {
		if (opt_test) continue;
		n++; name = bpf_map__name(map); fd = bpf_map__fd(map);
		P("Storing map fd #%d %d [ %s ]", n, fd, name);
		if (sd_pid_notifyf_with_fds( 0, false, &fd, 1,
				"FDSTORE=1\nFDPOLL=0\nFDNAME=%s_v%d", name, fd_version ) <= 0)
			EC("sd_notify fdstore failed for map #%d [ %s ]", n, name); }

	// Report success or hang forever in no-pins test-mode
	if (!opt_test) P("Successfully loaded eBPF and stored all maps with systemd");
	else if (strlen(opt_pin)) P("Loaded/pinned all eBPF objects in test-mode, exiting");
	else {
		P("Running in test-mode until stopped by signal");
		sleep(2147483647); err_exit = 0; goto err_cleanup; }
	return 0;

	err_cleanup: ebpf__destroy(skel); return err_exit;
}
