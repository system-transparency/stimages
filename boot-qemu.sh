#! /bin/bash
set -eu

STBOOT_ISO="$1"; shift
GUEST_OVMF_VARS="$1"; shift
[ $# -gt 0 ] && { QEMU_STDATA_DRIVE="$1"; shift; }
[ $# -gt 0 ] && { QEMU_RAM="$1"; shift; }
[ $# -gt 0 ] && { DISPLAY_MODE="$1"; shift; }
[ $# -gt 0 ] && { OVMF_CODE="$1"; shift; }

QEMU_RAM=${QEMU_RAM-4G}
QEMU_STDATA_DRIVE=${QEMU_STDATA_DRIVE-}
DISPLAY_MODE=${DISPLAY_MODE--nographic} # If console=ttyS0,115200: '-nographic'; else '-display gtk'.
OVMF_CODE=${OVMF_CODE-/usr/share/OVMF/OVMF_CODE.fd}

do_boot() {
    qemu-system-x86_64 \
	-accel kvm \
	-accel tcg \
	-no-reboot \
	-pidfile qemu.pid \
	-drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
	-drive if=pflash,format=raw,file="$GUEST_OVMF_VARS" \
	-object rng-random,filename=/dev/urandom,id=rng0 \
	-device virtio-rng-pci,rng=rng0 \
	-rtc base=localtime \
	-m "$QEMU_RAM" \
	"$DISPLAY_MODE" \
	$QEMU_STDATA_DRIVE \
	-drive file="$STBOOT_ISO",format=raw,if=none,media=cdrom,id=drive-cd1,readonly=on \
	-device ahci,id=ahci0 -device ide-cd,bus=ahci0.0,drive=drive-cd1,id=cd1,bootindex=1 \
	-cpu host,vmx=on
}

do_boot
