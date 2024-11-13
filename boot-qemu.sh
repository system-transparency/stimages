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
    if [[ -v DISABLE_TPM ]]; then
      if [ ! -d "/tmp/mytpm1" ]; then
        mkdir -p /tmp/mytpm1/localca
        TPM_STATE_PATH=/tmp/mytpm1 TPM_CONFIG_PATH=$(pwd)/contrib/stvmm swtpm_setup --tpm2 \
          --createek --create-ek-cert \
          --tpmstate /tmp/mytpm1 --config contrib/stvmm/swtpm_setup.conf
      fi
      swtpm socket --tpmstate dir=/tmp/mytpm1 \
        --ctrl type=unixio,path=/tmp/mytpm1/swtpm-sock \
        --tpm2 \
        --log level=20 --daemon --pid file=/tmp/mytpm1/swtpm-sock.pid
      TPM_DEV="-chardev socket,id=chrtpm,path=/tmp/mytpm1/swtpm-sock -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0"
    fi

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
	-cpu host,vmx=on \
	-netdev user,id=net0,net=10.0.2.0/24,dhcpstart=10.0.2.15,dns=8.8.8.8,hostfwd=tcp::2222-:22 \
	-device virtio-net-pci,netdev=net0,mac=52:54:00:12:34:56
}

do_boot
