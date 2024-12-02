#!/bin/bash

export PATH=$PATH:/root/go/bin/
export PATH=$PATH:/c/config/stvmm-hypervisor/overlays/vanilla/usr/sbin/
export STMGR_VERSION=6cdcb68b924367a5b2894d9aa4f2bd93420327c8

apt update
apt upgrage -y
apt install -y systemd ncat cpio build-essential util-linux pigz qemu-system swtpm swtpm-tools mmdebstrap parted gzip golang

cd /c/
./build-stmgr
make CONFIG=config/stvmm-guest all
cp build/stimage.{json,zip,zip.endorsement} config/stvmm-hypervisor/overlays/vanilla/var/lib/stvmm/
cp build/stboot.iso.endorsement config/stvmm-hypervisor/overlays/vanilla/var/lib/stvmm/
cp contrib/endorsement-signing.pub contrib/endorsement-signing.key config/stvmm-hypervisor/overlays/vanilla/var/lib/stvmm/
make CONFIG=config/stvmm-hypervisor clean boot-stvmm
bash
