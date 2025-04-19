# Makefile for eBPF loader binary from opensnitch/Makefile

KERNEL_DIR := $(shell \
	dir=/usr/src/linux dir_chk=$$dir/include; \
	[ -d "$$dir_chk" ] || dir=/lib/modules/`uname -r`/source dir_chk=$$dir; \
	[ -d "$$dir_chk" ] || dir=; \
	echo "$$dir" )
KERNEL_HEADERS := /usr/src/linux-headers-$(shell uname -r)/

CC := clang
LLC := llc
LLVM_STRIP := llvm-strip

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
	EBPF_EXTRA_FLAGS := "-D__LINUX_ARM_ARCH__=7"
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
	$(EBPF_EXTRA_FLAGS) \
	-Wunused \
	-Wno-unused-value \
	-Wno-gnu-variable-sized-type-not-at-end \
	-Wno-address-of-packed-member \
	-Wno-tautological-compare \
	-Wno-unknown-warning-option \
	-Wno-duplicate-decl-specifier \
	-fno-stack-protector \
	-fcf-protection \
	-g -O2 -emit-llvm

APP_CFLAGS := -g -Wall -Ibuild
APP_LDFLAGS := $(LDFLAGS) $(EXTRA_LDFLAGS)


all: leco-ebpf-load

clean:
	rm -rf build leco-ebpf-load

.SUFFIXES:


# libbpf + bpftool

build build/libbpf build/bpftool:
	mkdir -p $@

bpftool/libbpf/src:
	ln -s ../../libbpf/src bpftool/libbpf/src

build/libbpf.a: $(wildcard libbpf/src/*.[ch] libbpf/src/Makefile) | build/libbpf
	$(MAKE) -C libbpf/src BUILD_STATIC_ONLY=1 \
		OBJDIR=../../build/libbpf DESTDIR=../../build/ INCLUDEDIR= LIBDIR= UAPIDIR= install

build/bpftool/bootstrap/bpftool: | build/bpftool bpftool/libbpf/src
	$(MAKE) ARCH= CROSS_COMPILE= OUTPUT=../../build/bpftool/ -C bpftool/src bootstrap


# .bc -> .o -> .skel.h -> main binary

build/ebpf.bc: ebpf.c | build build/libbpf.a
	$(CC) $(EBPF_CFLAGS) -c -o $@ $<

build/ebpf.o: build/ebpf.bc $(wildcard build/bpf/*.[ch]) | build
	$(LLC) -march=bpf -mcpu=generic -filetype=obj -o $@ $<
	$(LLVM_STRIP) -g $@

build/ebpf.skel.h: build/ebpf.o | build build/bpftool/bootstrap/bpftool
	./build/bpftool/bootstrap/bpftool gen skeleton $< > $@

leco-ebpf-load: loader.c build/ebpf.skel.h build/libbpf.a
	$(CC) $< build/libbpf.a $(APP_CFLAGS) $(ALL_LDFLAGS) -lelf -lz -o $@
