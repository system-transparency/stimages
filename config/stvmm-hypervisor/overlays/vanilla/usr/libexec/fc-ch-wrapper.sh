#! /bin/bash

# This script is part of stvmm. It calls cloud-hypervisor with arguments read
# from a Firecracker config file.

CLOUD_HV="/usr/sbin/cloud-hypervisor"

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <Firecracker config file>"
    exit 1
fi

KERNEL_PATH=$(cat "$1" | jq -r '."boot-source".kernel_image_path')
INITRD_PATH=$(cat "$1" | jq -r '."boot-source".initrd_path')
CMDLINE=$(cat "$1" | jq -r '."boot-source".boot_args')
MEM_SIZE=$(cat "$1" | jq -r '."machine-config".mem_size_mib')
VCPU_COUNT=$(cat "$1" | jq -r '."machine-config".vcpu_count')
MAC=$(cat "$1" | jq -r '."network-interfaces"[0].guest_mac')
DEV_NAME=$(cat "$1" | jq -r '."network-interfaces"[0].host_dev_name')
IFACE_ID=$(cat "$1" | jq -r '."network-interfaces"[0].iface_id')
VSOCK_CID=$(cat "$1" | jq -r '.vsock.guest_cid')
VSOCK_PATH=$(cat "$1" | jq -r '.vsock.uds_path')

exec "$CLOUD_HV" \
  --kernel "$KERNEL_PATH" \
  --initramfs "$INITRD_PATH" \
  --cmdline "$CMDLINE" \
  --cpus "boot=$VCPU_COUNT" \
  --memory "size=${MEM_SIZE}M" \
  --serial tty \
  --net "tap=${DEV_NAME},mac=${MAC},id=${IFACE_ID}" \
  --vsock "cid=3,socket=$VSOCK_PATH"
