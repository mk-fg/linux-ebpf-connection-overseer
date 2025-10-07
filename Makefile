# Makefile for eBPF loader binary

# Make sure to adjust those when building for non-running kernel
KERNEL_DIR := $(shell \
	dir=/usr/src/linux dir_chk=$$dir/include; \
	[ -d "$$dir_chk" ] || dir=/lib/modules/`uname -r`/source dir_chk=$$dir; \
	[ -d "$$dir_chk" ] || dir=; \
	echo "$$dir" )
KERNEL_HEADERS := /usr/src/linux-headers-$(shell uname -r)/

CC := clang
LLC := llc
STRIP := llvm-strip
CMAKE := cmake
NIM := nim
SED := sed

ARCH := $(shell uname -m)
ifeq ($(ARCH),x86_64)
	ARCH := x86
else ifeq ($(ARCH),i686)
	ARCH := x86
else ifeq ($(ARCH),armv7l)
	ARCH := arm
else ifeq ($(ARCH),aarch64)
	ARCH := arm64
endif
ifeq ($(ARCH),arm)
	EBPF_EXTRA_CFLAGS := "-D__LINUX_ARM_ARCH__=7"
endif

EBPF_CFLAGS = -I. \
	-I$(KERNEL_HEADERS)/arch/$(ARCH)/include/generated/ \
	-I$(KERNEL_HEADERS)/include \
	-include $(KERNEL_DIR)/include/linux/kconfig.h \
	-I$(KERNEL_DIR)/include \
	-I$(KERNEL_DIR)/include/uapi \
	-I$(KERNEL_DIR)/include/generated/uapi \
	-I$(KERNEL_DIR)/arch/$(ARCH)/include \
	-I$(KERNEL_DIR)/arch/$(ARCH)/include/generated \
	-I$(KERNEL_DIR)/arch/$(ARCH)/include/uapi \
	-I$(KERNEL_DIR)/arch/$(ARCH)/include/generated/uapi \
	-I$(KERNEL_DIR)/tools/testing/selftests/bpf/ \
	-D__KERNEL__ -D__BPF_TRACING__ -Wno-unused-value -Wno-pointer-sign \
	-D__TARGET_ARCH_$(ARCH) -Wno-compare-distinct-pointer-types \
	$(EBPF_EXTRA_CFLAGS) \
	-Wunused \
	-Wno-gnu-variable-sized-type-not-at-end \
	-Wno-address-of-packed-member \
	-Wno-duplicate-decl-specifier \
	-fno-stack-protector \
	-fcf-protection \
	-g -O2 -emit-llvm
EBPF_STRIP := $(STRIP) -g

BIN_CFLAGS := -Wall -Ibuild $(BIN_EXTRA_CFLAGS)
BIN_LDFLAGS := $(LDFLAGS) $(BIN_EXTRA_LDFLAGS)
BIN_STRIP := $(STRIP)


all: leco-ebpf-load leco-sdl-widget leco-sdl-widget.ini

clean:
	rm -rf build leco-ebpf-load leco-sdl-widget leco-sdl-widget.ini

.SUFFIXES:


# leco-ebpf-load: libbpf, bpftool, sd-daemon

build build/libbpf build/bpftool:
	mkdir -p $@

bpftool/libbpf/src:
	ln -s ../../libbpf/src bpftool/libbpf/src

build/libbpf.a: $(wildcard libbpf/src/*.[ch] libbpf/src/Makefile) | build/libbpf
	$(MAKE) -C libbpf/src BUILD_STATIC_ONLY=1 \
		OBJDIR=../../build/libbpf DESTDIR=../../build/ INCLUDEDIR= LIBDIR= UAPIDIR= install

build/bpftool/bootstrap/bpftool: | build/bpftool bpftool/libbpf/src
	$(MAKE) ARCH= CROSS_COMPILE= OUTPUT=../../build/bpftool/ -C bpftool/src bootstrap

build/sd-daemon/libsd-daemon.a: $(wildcard sd-daemon/*.[ch] sd-daemon/configure sd-daemon/*.in)
	cp -r sd-daemon/. build/sd-daemon
	cd build/sd-daemon && ./configure && $(MAKE)


# leco-ebpf-load - .bc -> .o -> .skel.h -> wrapper binary

build/ebpf.bc: ebpf.c | build build/libbpf.a
	$(CC) $(EBPF_CFLAGS) -c -o $@ $<

build/ebpf.o: build/ebpf.bc $(wildcard build/bpf/*.[ch]) | build
	$(LLC) -march=bpf -mcpu=generic -filetype=obj -o $@ $<
	$(EBPF_STRIP) $@

build/ebpf.skel.h: build/ebpf.o | build build/bpftool/bootstrap/bpftool
	./build/bpftool/bootstrap/bpftool gen skeleton $< > $@

leco-ebpf-load: loader.c build/ebpf.skel.h build/libbpf.a build/sd-daemon/libsd-daemon.a
	$(CC) $< \
		-Ibuild/sd-daemon build/libbpf.a build/sd-daemon/libsd-daemon.a \
		$(BIN_CFLAGS) $(BIN_LDFLAGS) -lelf -lz -o $@
	$(BIN_STRIP) $@


# leco-sdl-widget: tinyspline dependency

build/tinyspline:
	mkdir -p $@

build/tinyspline/lib/libtinyspline.a: $(wildcard tinyspline/src/*.[ch] tinyspline/src/CMakeLists.txt) | build/tinyspline
	$(CMAKE) -B build/tinyspline \
		-DTINYSPLINE_BUILD_TESTS=False -DTINYSPLINE_ENABLE_CXX=False \
		-DTINYSPLINE_BUILD_DOCS=False -DTINYSPLINE_BUILD_EXAMPLES=False \
		-DCMAKE_INSTALL_PREFIX=build/tinyspline tinyspline
	$(CMAKE) --build build/tinyspline --target install

build/tinyspline/include/tinyspline.h: build/tinyspline/lib/libtinyspline.a


# leco-sdl-widget and its config file

leco-sdl-widget.ini: widget.ini
	$(SED) 's/^[^#[]/#\0/' $< > $@

leco-sdl-widget: widget.nim build/tinyspline/lib/libtinyspline.a build/tinyspline/include/tinyspline.h
	$(NIM) c -p=nsdl3 -d:release -d:strip -d:lto_incremental --opt:speed -o=leco-sdl-widget $<


###
