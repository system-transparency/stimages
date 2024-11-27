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
NETBOOT_URL ?= http://10.0.2.2:8080/$(STIMAGE_NAME)

# Cert/key file pairs to sign the image with. Set to empty string to disable signing.
SIGN ?= $(KEYS)

# Set to ./contain in order to run mmdebstrap in a container
CONTAIN ?=

####################
STIMAGE = $(BUILD)/$(STIMAGE_NAME).zip
KERNEL = $(BUILD)/$(BINDIST).vmlinuz
CMDLINE = $(BUILD)/$(BINDIST).kcmdline
INITRAMFS = $(BUILD)/$(BINDIST).cpio.gz
CA = keys/rootcert.pem keys/rootkey.pem
KEYS = keys/cert.pem keys/key.pem
STBOOT_ISO = $(BUILD)/stboot.iso
STBOOT_UKI = $(BUILD)/stboot.uki
STBOOT_FULL = $(BUILD)/stboot.endorsement.bin

####################
all: stimage
stimage: $(STIMAGE)
kernel: $(KERNEL)
cmdline: $(CMDLINE)
initramfs: $(INITRAMFS)
stboot-iso stboot: $(STBOOT_ISO)
stboot-uki: $(STBOOT_UKI)
stboot-ra: $(STBOOT_FULL)
boot: boot-qemu
clean:
	$(CONTAIN) rm -rf $(BUILD)
distclean: clean
	-rm -rf $(KEYS) $(CA) $(GUEST_DATADIR)

.PHONY: all stimage kernel cmdline initramfs boot clean distclean
####################
$(STIMAGE): $(INITRAMFS) $(KERNEL) $(CMDLINE) $(SIGN)
	./build-stimage $@ $(NETBOOT_URL).zip $(KERNEL) $(CMDLINE) $(INITRAMFS) $(SIGN)

# NOTE: Kernel is copied from initramfs (kernel modules are not)
# NOTE: Avoid circular dependencies by not depending on initramfs even though it's needed
$(KERNEL):
	./build-kernel $(CONFIG) $(FLAVOUR) $@

$(CMDLINE):
	./build-kcmdline $(CONFIG) $(FLAVOUR) $@

$(INITRAMFS): $(CONFIG)/pkgs/000base.pkglist
	$(CONTAIN) ./build-initramfs $(CONFIG) $@ $(FLAVOUR)

$(STBOOT_FULL): keys/rootcert.pem
	./contrib/stboot/build-stboot $(NETBOOT_URL).json $< iso,uki build/stboot.iso
$(STBOOT_ISO): keys/rootcert.pem
	./contrib/stboot/build-stboot $(NETBOOT_URL).json $< iso $@
$(STBOOT_UKI): keys/rootcert.pem
	./contrib/stboot/build-stboot $(NETBOOT_URL).json $< uki $@

####################
keys/rootcert.pem keys/rootkey.pem:
	(umask 0077 && mkdir -p keys)
	(cd keys && stmgr keygen certificate --isCA --validUntil 2099-01-01T00:00:00Z)

keys/cert.pem keys/key.pem:
	$(MAKE) keys/rootcert.pem
	(cd keys && stmgr keygen certificate --rootCert rootcert.pem --rootKey rootkey.pem --validUntil 2099-01-01T00:00:00Z)

####################
GUEST_DATADIR ?= hosts
GUEST_NAME ?= example-host
GUEST_OVMF_VARS ?= $(GUEST_DATADIR)/$(GUEST_NAME)/OVMF_VARS.fd
OVMF_DIR = /usr/share/OVMF
OVMF_CODE = $(OVMF_DIR)/OVMF_CODE.fd

ifdef DO_USE_STDATA
GUEST_STDATA ?= $(GUEST_DATADIR)/$(GUEST_NAME)/stdata.img
endif
ifdef GUEST_STDATA
QEMU_STDATA_DRIVE = -drive if=virtio,file=$(GUEST_STDATA),format=raw
endif

# Unable to get -nic 'user,guestfwd=tcp:10.0.2.2:8080-cmd:./serve-stimage.sh $(BUILD) $(STIMAGE_NAME)' to work with qemu-x86_64 version 7.2.7 (qemu-7.2.7-1.fc38)
wwworkaround: $(STIMAGE)
	(for e in json zip; do \
		ncat -lc "printf 'HTTP/1.1 200 OK\n\n'; cat $(BUILD)/$(STIMAGE_NAME).$$e" 0.0.0.0 8080; \
	done) &

$(GUEST_DATADIR)/$(GUEST_NAME):
	mkdir -p $@

$(GUEST_OVMF_VARS): $(GUEST_DATADIR)/$(GUEST_NAME)
	cp $(OVMF_DIR)/OVMF_VARS.fd $@

$(GUEST_STDATA): $(GUEST_DATADIR)/$(GUEST_NAME)
	./mkstdata.sh $@ $(GUEST_NAME) -dhcp

boot-qemu: $(STBOOT_ISO) $(OVMF_CODE) $(GUEST_OVMF_VARS) $(GUEST_STDATA) wwworkaround
	./boot-qemu.sh "$(STBOOT_ISO)" "$(GUEST_OVMF_VARS)" "$(QEMU_STDATA_DRIVE)"

boot-stvmm: $(STBOOT_FULL) $(OVMF_CODE) $(GUEST_OVMF_VARS) $(GUEST_STDATA)
	ENABLE_TPM=1 FORWARD_STVMM_API=1 ./boot-qemu.sh "$(STBOOT_ISO)" "$(GUEST_OVMF_VARS)" "$(QEMU_STDATA_DRIVE)"

.PHONY: wwworkaround boot-qemu

## Experimental VM creation using libvirt
VM_RAM ?= 4096
### For testing
VM_PERSIST ?= --transient
VM_NETWORK ?= user
### For real use
#VM_PERSIST ?= --autostart
#VM_NETWORK ?= bridge=br0

# NOTE: no nvram=FILE in --boot so guest EFI variables end up in ~/.config/libvirt/qemu/nvram/$(VM_NAME)_VARS.fd
install-vm: $(STBOOT_ISO) $(OVMF_CODE) $(GUEST_STDATA) wwworkaround
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
		--disk "$(STBOOT_ISO)",format=raw,readonly=on \
		--disk "$(GUEST_STDATA)",format=raw

.PHONY: install-vm
####################

# You don't need all of these installed for anything, but if you have
# all of them installed you should be able to build everything.
.PHONY: check-all-dependencies
check-all-dependencies:
	./check-deps chroot cpio find git go losetup mkfs mmdebstrap mount nc parted gzip podman qemu-system-x86_64 stmgr sudo umount virt-install
