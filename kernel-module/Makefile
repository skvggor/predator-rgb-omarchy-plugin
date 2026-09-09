obj-m += src/acer_rgb.o

ccflags-y += -I$(src)/src

KERNEL_DIR := /lib/modules/$(shell uname -r)/build
BUILD_DIR  := /tmp/acer-rgb-build
MODULE_NAME := acer_rgb

all:
	@mkdir -p $(BUILD_DIR)
	@rsync -a --delete --exclude='.git' --exclude='build' "$(CURDIR)/" $(BUILD_DIR)/
	$(MAKE) -C $(KERNEL_DIR) M=$(BUILD_DIR) modules
	@cp $(BUILD_DIR)/src/$(MODULE_NAME).ko "$(CURDIR)/"

install:
	@mkdir -p $(BUILD_DIR)
	@rsync -a --delete --exclude='.git' --exclude='build' "$(CURDIR)/" $(BUILD_DIR)/
	$(MAKE) -C $(KERNEL_DIR) M=$(BUILD_DIR) modules
	@rm -f /lib/modules/$(shell uname -r)/kernel/drivers/platform/x86/$(MODULE_NAME).ko
	@rm -f /lib/modules/$(shell uname -r)/updates/$(MODULE_NAME).ko
	@mkdir -p /lib/modules/$(shell uname -r)/extra
	@cp $(BUILD_DIR)/src/$(MODULE_NAME).ko /lib/modules/$(shell uname -r)/extra/
	@depmod -a

uninstall:
	@rm -f /lib/modules/$(shell uname -r)/extra/$(MODULE_NAME).ko
	@rm -f /etc/modules-load.d/$(MODULE_NAME).conf
	@depmod -a

clean:
	@rm -rf $(BUILD_DIR)

.PHONY: all install uninstall clean
