// See Makefile for how to build this and generate ebpf.skel.h for it
// Docs: https://docs.ebpf.io/ https://libbpf.readthedocs.io/en/latest/api.html

#include <stdio.h>
#include <unistd.h>
#include <getopt.h>
#include <spawn.h>
#include <sys/wait.h>

#include <bpf/bpf.h>
#include <bpf/libbpf.h>
#include <systemd/sd-daemon.h>

#include "build/ebpf.skel.h"


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
"Usage: %s [-h|--help] [-v|--verbose] [opts...]\n\n"
"Loads bundled network-monitoring eBPF programs, sets up maps for them.\n"
"Intended to persist eBPF objects in one of two ways:\n\n"
"- Default: store them as fds in systemd File Descriptor Store.\n"
"  Intended for running from ExecStartPre=+... line in a systemd service file\n"
"   (which also has Type=notify NotifyAccess=exec and FileDescriptorStoreMax=32).\n"
"  Detects running under systemd via sd_notify environment variables.\n"
"  Exits with error if not running under systemd in this mode.\n"
"  It does not work, at least with current systemd-257.5 - see issue-37192 there.\n"
"  Pinning with --pin-fdstore option can be used as a workaround.\n\n"
"- Pin all objects to bpffs, refreshing dir there as-needed (-p/--pin option).\n\n"
"If eBPF objects are already setup and stored/pinned, exits without doing anything.\n\n"
"  -v/--verbose - enable verbose logging about systemd and libbpf interactions to stderr.\n"
"  -p/--pin <path> - pin eBPF progs/maps/links in dir on bpffs. Example: /sys/fs/bpf/leco\n"
"  --pin-fdstore - store/replace pinned eBPF maps in systemd fdstore without version suffix.\n"
"\n", cmd );
	exit(err); }
#define usage(err) parse_opts_usage(err, argv[0]);

void parse_opts( int argc, char *argv[],
		int *opt_verbose, char **opt_pin, int *opt_pin_fdstore ) {
	extern char *optarg; extern int optind, opterr, optopt; int ch;
	static struct option opt_list[] = {
		{"help", no_argument, NULL, 1},
		{"verbose", no_argument, NULL, 2},
		{"pin", required_argument, NULL, 3},
		{"pin-fdstore", no_argument, NULL, 4} };
	while ((ch = getopt_long(argc, argv, ":hvp:", opt_list, NULL)) != -1) switch (ch) {
		case 'h': case 1: usage(0);
		case 'v': case 2: *opt_verbose = true; break;
		case 'p': case 3: *opt_pin = optarg; break;
		case 4: *opt_pin_fdstore = true; break;
		case '?': E(0, "unrecognized option [ %s ]\n", argv[optind-1]); usage(1);
		case ':':
			if (optopt >= 32) E(0, "missing argument for -%c\n", optopt);
			else E(0, "missing argument for --%s\n", opt_list[optopt-1].name);
			usage(1);
		default: usage(1); }
	if (optind < argc) {
		E(0, "unrecognized argument value [ %s ]\n", argv[optind]); usage(1); }
}


#define fd_version 1
#define fd_version_check "kprobe__tcp_v4_connect__v1"

int main(int argc, char **argv) {
	int opt_verbose = false, opt_pin_fdstore = false; char *opt_pin = "";
	parse_opts(argc, argv, &opt_verbose, &opt_pin, &opt_pin_fdstore);
	int n, fd, pin_mode = strlen(opt_pin), bpf_init = true;
	const char *name; char pin[1024], opt_pin_maps[512], opt_pin_links[512];

	// Check if eBPFs are already loaded/pinned
	if (!pin_mode) {
		// Note: systemd-257 does not pass fds and LISTEN_FDS to ExecStartPre=+...
		// So there's no good way to tell if eBPFs are already loaded without pins above
		// See https://github.com/systemd/systemd/issues/37192 for details
		char **fd_names;
		int fd_n = sd_listen_fds_with_names(false, &fd_names);
		if (fd_n < 0) E(1, "sd_listen_fds check failed");
		for (n = 0; n < fd_n; n++)
			if (!strcmp(fd_names[n], fd_version_check)) break;
		if (n < fd_n) { P("sd_listen_fds are setup already, exiting"); return 0; }
		else if (fd_n > 0) {
			P("sd_listen_fds version mismatch, re-initializing eBPFs");
			for (n = 0; n < fd_n; n++)
				if (sd_notifyf( false, "FDSTOREREMOVE=1\nFDNAME=%s",
						fd_names[n] ) <= 0 || close(SD_LISTEN_FDS_START + n))
					E(1, "sd_listen_fds fd-cleanup failed [ %s ]", fd_names[n]); } }

	else { // pin-mode
		snprintf(opt_pin_maps, sizeof(opt_pin_maps), "%s/maps", opt_pin);
		snprintf(opt_pin_links, sizeof(opt_pin_links), "%s/links", opt_pin);
		if (!access(opt_pin, F_OK)) {
			snprintf(pin, 1024, "%s/%s", opt_pin_links, fd_version_check);
			if ( access(pin, F_OK) ||
					access(opt_pin_maps, F_OK) || access(opt_pin_links, F_OK) ) {
				P("Pinned eBPF path does not match current progs/maps, replacing it");
				if (strncmp(opt_pin, "/sys/fs/bpf/", 12)) // to avoid "rm -rf /usr" or such
					E(1, "eBPF pins path to remove/replace must start with /sys/fs/bpf/");
				extern char *environ[];
				if (posix_spawnp( NULL, "rm", NULL, NULL,
						(char*[]){"rm", "-rf", "--", opt_pin, NULL}, environ ))
					E(1, "Failed to remove old-version bpf-pins dir: %s", pin);
				wait(NULL); }
			else if (opt_pin_fdstore) bpf_init = false;
			else { P("Correct eBPFs are pinned already, exiting"); return 0; } } }

	// Init/load/attach/pin eBPFs and maps
	struct ebpf *skel;
	if (opt_verbose) libbpf_set_print(libbpf_print_fn);
	if (bpf_init) {
		if (!(skel = ebpf__open_and_load())) E(1, "Failed to open eBPF skeleton");
		if (pin_mode) { // attachment links are also pinned separately below
			if ( !bpf_object__pin_programs(skel->obj, opt_pin)
					&& !bpf_object__pin_maps(skel->obj, opt_pin_maps) )
				P("Pinned eBPF programs/maps to [ %s ]", opt_pin);
			else EC("Failed to pin eBPF progs/maps to [ %s ]", opt_pin); }

		// Attach eBPF programs, store/pin links
		// It's not enough to hold program fds open for them to work, but enough
		//  to hold link fds, and pinning those with version is useful for later checks.
		// There's no bpf_object__pin_links to pin them all automatically, not sure why.
		n = 0; struct bpf_program *prog; struct bpf_link *link;
		bpf_object__for_each_program(prog, skel->obj) {
			n++; name = bpf_program__name(prog);
			if (!(link = bpf_program__attach(prog)))
				EC("Failed to attach program #%d [ %s ]", n, name);
			if (!pin_mode) {
				fd = bpf_link__fd(link); // link-fd should keep program around as well
				P("Storing program-link fd #%d %d [ %s ]", n, fd, name);
				if (sd_pid_notifyf_with_fds( 0, false, &fd, 1,
						"FDSTORE=1\nFDPOLL=0\nFDNAME=%s__v%d", name, fd_version ) <= 0) {
					EC("sd_notify fdstore failed for prog-link #%d [ %s ]", n, name); } }
			else if (snprintf( pin, 1024, "%s/%s__v%d",
					opt_pin_links, name, fd_version ) <= 0 || bpf_link__pin(link, pin) )
				EC("Failed to pin prog-link #%d [ %s ] to [ %s ]", n, name, pin); }

		// Store eBPF maps with systemd fdstore
		if (!pin_mode) {
			n = 0; struct bpf_map *map;
			bpf_object__for_each_map(map, skel->obj) {
				n++; name = bpf_map__name(map); fd = bpf_map__fd(map);
				P("Storing map fd #%d %d [ %s ]", n, fd, name);
				if (sd_pid_notifyf_with_fds( 0, false, &fd, 1,
						"FDSTORE=1\nFDPOLL=0\nFDNAME=%s_v%d", name, fd_version ) <= 0)
					EC("sd_notify fdstore failed for map #%d [ %s ]", n, name); } } }

	// Clear/store only specific non-versioned maps with --pin-fdstore option
	if (pin_mode && opt_pin_fdstore) {
		char *pin_objs[] = {"conn_table", "updates"};
		for (n = 0; n < 2; n++) {
			snprintf(pin, 1024, "%s/%s", opt_pin_maps, name = pin_objs[n]);
			if ((fd = bpf_obj_get(pin)) <= 0) E(1, "Pinned obj_get failed [ %s ]", pin);
			if (sd_notifyf(false, "FDSTOREREMOVE=1\nFDNAME=%s", name) <= 0)
				E(1, "sd_listen_fds fd-cleanup failed [ %s ]", name);
			if (sd_pid_notifyf_with_fds( 0, false, &fd, 1,
					"FDSTORE=1\nFDPOLL=0\nFDNAME=%s", name ) <= 0)
				E(1, "sd_notify fdstore failed for prog-link #%d [ %s ]", n, name); } }

	// Report success/failure
	P("Successfully loaded and stored/pinned eBPF objects"); return 0;
	err_cleanup: ebpf__destroy(skel); return 1;
}
