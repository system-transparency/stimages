# Build directory, where output ends up
BUILD ?= build

# What config to build
CONFIG ?= config/example

# What flavour of the config to build
FLAVOUR ?= vanilla

# Name of the ST image to build
STIMAGE_NAME ?= stimage

# Basename of the kernel, kernel cmdline and initramfs files
BINDIST ?= debian-bookworm-amd64

# URL to download image from
NETBOOT_URL ?= http://10.0.2.2:8080/$(STIMAGE_NAME).zip

# Cert/key file pairs to sign the image with. Set to empty string to disable signing.
SIGN ?= $(KEYS)

####################
STIMAGE = $(BUILD)/$(STIMAGE_NAME).zip
KERNEL = $(BUILD)/$(BINDIST).vmlinuz
CMDLINE = $(BUILD)/$(BINDIST).kcmdline
INITRAMFS = $(BUILD)/$(BINDIST).cpio.gz
CA = keys/rootcert.pem keys/rootkey.pem
KEYS = keys/cert.pem keys/key.pem
STBOOT = $(BUILD)/stboot.iso

####################
all: stimage
stimage: $(STIMAGE)
kernel: $(KERNEL)
cmdline: $(CMDLINE)
initramfs: $(INITRAMFS)
boot: boot-qemu
clean:
	-sudo rm -rf $(BUILD)/rootfs
	-rm -rf $(BUILD)
	@echo "NOTE: Leaving keys and guest dir ($(GUEST_DATADIR)). Try make distclean."
distclean: clean
	-rm -rf $(KEYS) $(CA) $(GUEST_DATADIR)
	-@([ -n "$$GOPATH" ] && [ -d "$$GOPATH" ] && echo "NOTE: Leaving GOPATH ($$GOPATH) as is")

.PHONY: all stimage kernel cmdline initramfs boot clean distclean
####################
$(STIMAGE): $(KERNEL) $(CMDLINE) $(INITRAMFS) $(SIGN)
	./build-stimage $@ $(NETBOOT_URL) $^

# NOTE: Kernel is copied from initramfs (kernel modules are not)
$(KERNEL): $(INITRAMFS)
	./build-kernel $(CONFIG) $(FLAVOUR) $@

$(CMDLINE):
	./build-kcmdline $(CONFIG) $(FLAVOUR) $@

$(INITRAMFS): $(CONFIG)/pkgs/000base.pkglist
	./build-initramfs $(CONFIG) $(FLAVOUR) $@ $^

$(STBOOT): keys/rootcert.pem
	./contrib/stboot/build-stboot $(STIMAGE_NAME) $@ $^

####################
keys/rootcert.pem keys/rootkey.pem:
	(umask 0077 && mkdir -p keys)
	(cd keys && stmgr keygen certificate --isCA)

keys/cert.pem keys/key.pem:
	$(MAKE) keys/rootcert.pem
	(cd keys && stmgr keygen certificate --rootCert rootcert.pem --rootKey rootkey.pem)

####################
QEMU_RAM ?= 4G
GUEST_DATADIR ?= hosts
GUEST_NAME ?= example-host
GUEST_STDATA ?= $(GUEST_DATADIR)/$(GUEST_NAME)/stdata.img
GUEST_OVMF_VARS ?= $(GUEST_DATADIR)/$(GUEST_NAME)/OVMF_VARS.fd
OVMF_DIR = /usr/share/OVMF
OVMF_CODE = $(OVMF_DIR)/OVMF_CODE.fd
# For kernel booted with console=ttyS0,115200, use -nographic. Else use -display gtk.
DISPLAY_MODE ?= -nographic

# Unable to get -nic 'user,guestfwd=tcp:10.0.2.2:8080-cmd:./serve-stimage.sh $(BUILD) $(STIMAGE_NAME)' to work with qemu-x86_64 version 7.2.7 (qemu-7.2.7-1.fc38)
wwworkaround:
	(for e in json zip; do \
		nc -lc "echo -e 'HTTP/1.1 200 OK\n'; cat $(BUILD)/$(STIMAGE_NAME).$$e" 0.0.0.0 8080; \
	done) &

$(GUEST_DATADIR)/$(GUEST_NAME):
	mkdir -p $@

$(GUEST_OVMF_VARS): $(GUEST_DATADIR)/$(GUEST_NAME)
	cp $(OVMF_DIR)/OVMF_VARS.fd $@

$(GUEST_STDATA): $(GUEST_DATADIR)/$(GUEST_NAME)
	./mkstdata.sh $@ $(GUEST_NAME) -dhcp

boot-qemu: $(STBOOT) $(OVMF_CODE) $(GUEST_OVMF_VARS) $(GUEST_STDATA) wwworkaround
	qemu-system-x86_64 \
		-drive if=pflash,format=raw,readonly=on,file="$(OVMF_CODE)" \
		-drive if=pflash,format=raw,file="$(GUEST_OVMF_VARS)" \
		-enable-kvm -M q35 \
		-object rng-random,filename=/dev/urandom,id=rng0 \
		-device virtio-rng-pci,rng=rng0 \
		-rtc base=localtime \
		-m $(QEMU_RAM) \
		$(DISPLAY_MODE) \
		-drive if=virtio,file=$(GUEST_STDATA),format=raw \
		-drive file="$(STBOOT)",format=raw,if=none,media=cdrom,id=drive-cd1,readonly=on \
		-device ahci,id=ahci0 -device ide-cd,bus=ahci0.0,drive=drive-cd1,id=cd1,bootindex=1

## Experimental VM creation using libvirt
VM_RAM ?= 4096
### For testing
VM_PERSIST ?= --transient
VM_NETWORK ?= user
### For real use
#VM_PERSIST ?= --autostart
#VM_NETWORK ?= bridge=br0

# NOTE: no nvram=FILE in --boot so guest EFI variables end up in ~/.config/libvirt/qemu/nvram/$(VM_NAME)_VARS.fd
install-vm: $(STBOOT) $(OVMF_CODE) $(GUEST_STDATA) wwworkaround
	virt-install \
		--debug \
		--name $(GUEST_NAME) \
		--osinfo debian12 \
		$(VM_PERSIST) \
		--import \
		--boot loader="$(OVMF_CODE)",loader.readonly=yes,loader.type=pflash,loader.secure=no \
		--boot nvram.template="$(OVMF_DIR)/OVMF_VARS.fd" \
		--virt-type kvm \
		--graphics none \
		--memory $(VM_RAM) \
		--rng /dev/urandom \
		--network $(VM_NETWORK) \
		--disk "$(STBOOT)",format=raw,readonly=on \
		--disk "$(GUEST_STDATA)",format=raw

####################

# You don't need all of these installed for anything, but if you have
# all of them installed you should be able to build everything.
.PHONY: check-all-dependencies
check-all-dependencies:
	./check-deps chroot cpio find git go losetup mkfs mmdebstrap mount nc parted pigz podman qemu-system-x86_64 stmgr sudo umount virt-install
