#! /bin/bash -x
set -eu

# Test the ST getting started guide by running the commands in project/docs/content/docs/introduction/build.md.
# NOTE: This file is manually maintained -- when the docs are being changed, someone need to update this file.

# Usage:
#   podman run -it --rm -v "${PWD}:/c:z" debian:bookworm /c/test/getting-started.sh

[ $# -gt 0 ] && { STIMAGESVER="$1"; shift; }
STIMAGESVER=${STIMAGESVER-main}

apt-get update
apt-get -y install sudo

cd /c

## project/docs/content/docs/introduction/build.md
### Prepare for building
sudo apt install -y golang-go git cpio pigz ca-certificates
sudo apt install -y mmdebstrap sudo

git clone -b "$STIMAGESVER" https://git.glasklar.is/system-transparency/core/stimages.git
cd stimages

mkdir -p go/bin; GOBIN="$(realpath go/bin)"; export GOBIN
export PATH="$GOBIN":"$PATH"
go install system-transparency.org/stmgr@v0.3.1

(umask 0077 && mkdir keys)
(cd keys && stmgr keygen certificate --isCA)
(cd keys && stmgr keygen certificate --rootCert rootcert.pem --rootKey rootkey.pem)

### Prepare for booting in QEMU
sudo apt install -y qemu-system-x86 ovmf ncat

## Build your own ST bootloader image
contrib/stboot/build-stboot http://10.0.2.2:8080/my-os.json keys/rootcert.pem

## Build your own OS package
echo myrootpassword > config/example/pw.root
./build-initramfs config/example my-os.cpio.gz

stmgr ospkg create \
	  --label="My example ST package" \
	  --initramfs=my-os.cpio.gz \
	  --kernel=my-os.vmlinuz \
	  --cmdline="console=ttyS0,115200n8 ro rdinit=/lib/systemd/systemd systemd.log_level=debug" \
	  --url=http://10.0.2.2:8080/my-os.zip \
	  --out=my-os.zip

stmgr ospkg sign \
	  --cert keys/cert.pem \
	  --key keys/key.pem \
	  --ospkg my-os

## Boot the OS package
(for e in json zip; do nc -lc "printf 'HTTP/1.1 200 OK\n\n'; cat my-os.$e" 0.0.0.0 8080; done) &
cp /usr/share/OVMF/OVMF_VARS.fd OVMF_VARS.fd
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

bash -
