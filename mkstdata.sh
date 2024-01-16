#! /bin/bash
set -eu

# Create STDATA disk image.
# NOTE: Requires root for losetup, parted (for informing the kernel), mkfs, mount, chown and umount.

# TODO: Quiet this script to make it easier to spot errors and grab the ssh host key printout.

usage() {
    echo "usage: $(basename "$0") IMAGE HOSTNAME [-dhcp] [-4 IPV4] [-m4 V4MASK] [-gw4 V4GW] [-6 IPV6] [-m6 V6MASK] [-gw6 V6GW]"
    exit 1
}

IMG="$1"; shift
HOSTNAME="$1"; shift
DHCP=no
MASK4=24
MASK6=64
while [ $# -gt 0 ]; do
    case "$1" in
	-4) IPV4="$2"; shift 2;;
	-6) IPV6="$2"; shift 2;;
	-dhcp) DHCP=yes; shift 1;;
	-gw4) GW4="$2"; shift 2;;
	-gw6) GW6="$2"; shift 2;;
	-m4) MASK4="$2"; shift 2;;
	-m6) MASK6="$2"; shift 2;;
	*) usage;;
    esac
done
if [ "$DHCP" = no ]; then
    [[ -n "${IPV4-}" && -z "${GW4-}" ]] && GW4=$(ipcalc --minaddr --no-decorate "${IPV4}/${MASK4}")
    [[ -n "${IPV6-}" && -z "${GW6-}" ]] && GW6=$(ipcalc --minaddr --no-decorate "${IPV6}/${MASK6}")1
fi
#echo -e "IMAGE=$IMG\nHOSTNAME=$HOSTNAME\nDHCP=$DHCP\nIPV4=${IPV4--}\nV4MASK=${MASK4--}\nV4GW=${GW4--}\nIPV6=${IPV6--}\nV6MASK=${MASK6--}\nV6GW=${GW6--}\n"

[ -e "$IMG" ] && { echo "ERROR: $IMG exists"; exit 1; }

# Create the fs image and mount it
[ "$(sudo losetup --associated "$IMG" | wc -l)" -eq 0 ] || { echo "ERROR: $IMG already has a loopdev"; exit 1; }
echo "INFO: creating disk image for /stdata: $IMG"
truncate --size 32M "$IMG"
loopdev=$(sudo losetup --find --nooverlap --show "$IMG")
sudo parted --script "$loopdev" mklabel gpt
sudo parted --script "$loopdev" mkpart primary ext4 2048s -- -34s
sudo parted --script "$loopdev" name 1 STDATA
lsblk "$loopdev"
sudo mkfs.ext4 "${loopdev}p1"
sudo mkdir -p mnt
sudo mount "${loopdev}p1" mnt
localuser=$(id -u)
sudo chown "$localuser" mnt

# Hostname
mkdir -p mnt/etc
echo "$HOSTNAME" > mnt/etc/hostname

# Networking
mkdir -p mnt/etc/systemd/network
f=mnt/etc/systemd/network/10-generated.network
cat > $f <<'EOF'
[Match]
Name = enp*
[Network]
EOF
if [ "$DHCP" = yes ]; then
    echo 'DHCP = yes' >> $f
else
    if [[ -z "${IPV4-}" && -z "${IPV6-}" ]]; then
	IPV4=$(drill -Q "$HOSTNAME" a    | grep -E ^[0-9]+ | head -1)
	IPV6=$(drill -Q "$HOSTNAME" aaaa | grep -E ^[0-9]+ | head -1)
    fi
    [[ -n "${IPV4-}" && -z "${GW4-}" ]] && GW4=$(ipcalc --minaddr --no-decorate "${IPV4}/${MASK4}")
    [[ -n "${IPV6-}" && -z "${GW6-}" ]] && GW6=$(ipcalc --minaddr --no-decorate "${IPV6}/${MASK6}")1
    if [ -n "${IPV4-}" ]; then
	echo "Address = ${IPV4}/${MASK4}" >> $f
	echo "Gateway = $GW4" >> $f
    fi
    if [ -n "${IPV6-}" ]; then
	echo "Address = ${IPV6}/${MASK6}" >> $f
	echo "Gateway = $GW6" >> $f
    fi
fi

# Generate sshd host key
mkdir -p mnt/etc/ssh
ssh-keygen -q -N '' -t ed25519 -f mnt/etc/ssh/ssh_host_ed25519_key
echo "SSH_HOST_KEY_$HOSTNAME=$(ssh-keygen -l -f mnt/etc/ssh/ssh_host_ed25519_key)"

# Create Ansible vault pw files
host_vault_path="mnt/etc/vault/$(echo "$HOSTNAME" | cut -d . -f 1)_vault_secret"
mkdir -p "$(dirname "$host_vault_path")"
(umask 0077 && base64 -w 0 /dev/urandom | head -c 42 > "$host_vault_path")

# Clean up
# TODO: move into a function and trap into it
while findmnt mnt; do echo "waiting for mnt to be unmounted"; sudo umount mnt; sleep 1; done
rmdir mnt
sudo losetup -d "$loopdev"

# TODO: print help about informing kernel of disk layout, to find partition #1 (${loopdev}p1)
echo "INFO: created $IMG, can be attached like this: sudo losetup --find --nooverlap --show $IMG"
