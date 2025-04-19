# Makefile for eBPF code from opensnitch/Makefile

# -- Added /usr/src/linux check here for my setup
# -- Old /lib/modules/ and /usr/src/linux-headers-* are supposedly for normal distros
KERNEL_DIR ?= $(shell \
	dir=/usr/src/linux dir_chk=$$dir/include; \
	[ -d "$$dir_chk" ] || dir=/lib/modules/`uname -r`/source dir_chk=$$dir; \
	[ -d "$$dir_chk" ] || dir=; \
	echo "$$dir" )
KERNEL_HEADERS ?= /usr/src/linux-headers-$(shell uname -r)/

# -- Added LLVM_STRIP to remove debug info here
LLVM_STRIP ?= llvm-strip

CC = clang
LLC ?= llc
ARCH ?= $(shell uname -m)

# as in /usr/src/linux-headers-*/arch/
# TODO: extract correctly the archs, and add more if needed.
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
	# on previous archs, it fails with "SMP not supported on pre-ARMv6"
	EXTRA_FLAGS = "-D__LINUX_ARM_ARCH__=7"
endif

# -- Added couple flags here to suppress 6.6-6.12 kernel header warnings
SRC := $(wildcard *.c)
BIN := $(SRC:.c=.o)
CFLAGS = -I. \
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
	$(EXTRA_FLAGS) \
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

all: $(BIN)

%.bc: %.c $(wildcard %.h)
	$(CC) $(CFLAGS) -c $<

%.o: %.bc
	$(LLC) -march=bpf -mcpu=generic -filetype=obj -o $@ $<
	$(LLVM_STRIP) -g $@

clean:
	rm -f $(BIN)

.SUFFIXES:
