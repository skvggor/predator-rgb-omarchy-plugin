obj-m += src/acer_rgb.o

ccflags-y += -I$(src)/src

KERNEL_DIR ?= /lib/modules/$(shell uname -r)/build
MODULE_NAME := acer_rgb

# The kernel build system re-invokes make with M=$(M) unquoted, so a build
# directory containing a space breaks the recursion. A checkout under a path
# like "~/Dropbox/Linux Files/..." hits that, which is why the build directory
# is always created under TMPDIR rather than next to the sources.
#
# BUILD_DIR is always an unpredictable mktemp directory. It must never be a
# fixed path: a predictable directory under /tmp can be pre-created by another
# local user as a symlink, and a privileged build would then write through it.
# The installer passes its own mktemp -d; this default covers running make by
# hand.
ifeq ($(origin BUILD_DIR),undefined)
BUILD_DIR := $(shell mktemp -d "$${TMPDIR:-/tmp}/acer-rgb-build.XXXXXXXX")
endif

# This Makefile only compiles. It deliberately has no target that writes to
# /lib/modules, /etc or /usr, so it is harmless to run as root by accident and
# there is no privileged path for a modified Makefile to reach through it. The
# installer owns every system path: it builds as the invoking user and then
# copies the resulting .ko into place itself, verifying it first.

.PHONY: all clean

all:
	@mkdir -p $(BUILD_DIR)
	@rsync -a --delete --exclude='.git' --exclude='build' "$(CURDIR)/" "$(BUILD_DIR)/"
	$(MAKE) -C $(KERNEL_DIR) M=$(BUILD_DIR) modules

clean:
	@case "$(BUILD_DIR)" in \
	  *acer-rgb-build*) rm -rf -- "$(BUILD_DIR)" ;; \
	  *) echo "clean: refusing to remove $(BUILD_DIR): not a build directory" >&2; exit 1 ;; \
	esac
