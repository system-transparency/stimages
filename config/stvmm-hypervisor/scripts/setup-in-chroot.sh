#! /bin/sh
set -eu

# default hostname
echo "stvmm-hypervisor" > /etc/hostname

systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable stvmmd
systemctl enable ssh
