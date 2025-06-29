#! /bin/bash -x
set -eu

# Test the ST build guide by running the commands in project/docs/content/docs/introduction/build.md.
# NOTE: This file is manually maintained -- when the docs are being changed, someone need to update this file.

# Prerequisites:
# - Debian12 or podman
# - 1.2G free space on $TMPDIR (/tmp)
# - Internet access, for downloading Debian packages

# Usage:
#   test/getting-started.sh && rm -irf stimages
# Usage, running in a podman container:
#   podman run -it --rm -v "$PWD:/c" debian:bookworm-backports /c/test/getting-started.sh

[ $# -gt 0 ] && { STIMAGESVER="$1"; shift; } # git clone -b
STIMAGESVER=${STIMAGESVER-main}
[ $# -gt 0 ] && { STMGRVER="$1"; shift; } # go install @
STMGRVER=${STMGRVER-v0.6.6}

if [ -v container ]; then
    trap bash EXIT
    apt-get update
    apt-get -y install sudo
    cd /c
fi

## project/docs/content/docs/introduction/build.md

### Prepare for booting in an emulator
[ -z "$(command -v qemu-system-x86_64)" ] && sudo apt install -y qemu-system-x86 ovmf ncat

### Prepare for building
[ -z "$(command -v go)" ] && sudo apt install -y golang-1.23-go && export PATH="/usr/lib/go-1.23/bin/:$PATH"
[ -z "$(command -v update-ca-certificates)" ] && sudo apt install -y ca-certificates
[ -z "$(command -v git)" ] && sudo apt install -y git
[ -z "$(command -v cpio)" ] && sudo apt install -y cpio
[ -z "$(command -v pigz)" ] && sudo apt install -y pigz
[ -z "$(command -v mmdebstrap)" ] && sudo apt install -y mmdebstrap
# TODO: any or both of libsystemd-shared and man-db required? If so, update docs/content/docs/introduction/build.md
#find /usr/lib* -name libsystemd-shared\*.so -quit || sudo apt install -y libsystemd-shared
#[ ! -e FIXME ] && sudo apt install -y man-db

git clone -b "$STIMAGESVER" https://git.glasklar.is/system-transparency/core/stimages.git
pushd stimages
[ -v container ] || trap popd EXIT

mkdir -p go/bin; GOBIN="$(realpath go/bin)"; export GOBIN
export PATH="$GOBIN":"$PATH"
go install system-transparency.org/stmgr@"$STMGRVER"

(umask 0077 && mkdir keys)
(cd keys && stmgr keygen certificate --isCA)
(cd keys && stmgr keygen certificate --rootCert rootcert.pem --rootKey rootkey.pem)

## Build your own bootloader image
contrib/stboot/build-stboot http://10.0.2.2:8080/my-os.json keys/rootcert.pem

## Build your own OS package
echo myrootpassword > config/example/pw.root
./build-initramfs config/example my-os.cpio.gz

stmgr ospkg create \
	  --label="My example ST system" \
	  --initramfs=my-os.cpio.gz \
	  --kernel=my-os.vmlinuz \
	  --cmdline="console=ttyS0,115200n8 ro rdinit=/lib/systemd/systemd" \
	  --url=http://10.0.2.2:8080/my-os.zip \
	  --out=my-os.zip

stmgr ospkg sign \
	  --cert keys/cert.pem \
	  --key keys/key.pem \
	  --ospkg my-os

## Boot the OS package
cp /usr/share/OVMF/OVMF_VARS.fd OVMF_VARS.fd
(for e in json zip; do ncat -lc "printf 'HTTP/1.1 200 OK\n\n'; cat my-os.$e" 0.0.0.0 8080; done) &
qemu-system-x86_64 \
        -m 3G \
        -accel kvm \
        -accel tcg \
        -pidfile qemu.pid \
        -no-reboot \
        -nographic \
        -rtc base=localtime \
        -drive if=pflash,format=raw,file=/usr/share/OVMF/OVMF_CODE.fd,readonly=on \
        -drive if=pflash,format=raw,file=OVMF_VARS.fd \
        -object rng-random,filename=/dev/urandom,id=rng0 \
        -device virtio-rng-pci,rng=rng0 \
        -drive file="stboot.iso",format=raw,if=none,media=cdrom,id=drive-cd1,readonly=on \
        -device ahci,id=ahci0 -device ide-cd,bus=ahci0.0,drive=drive-cd1,id=cd1,bootindex=1
