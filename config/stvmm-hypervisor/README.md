This directory contains configuration for [stimages][] to build an
example ST OS image for running stvmmd.

The [build-initramfs][] script expects a number of files to exist in
this directory. Some of the paths depend on the FLAVOUR argument
passed to build-initramfs. The default FLAVOUR is 'vanilla'.

The steps performed are described below, in the order they are being
done.

[stimages]: https://git.glasklar.is/system-transparency/core/stimages
[build-initramfs]: https://git.glasklar.is/system-transparency/core/stimages/-/blob/main/build-initramfs


## Building the guest image

For now, the guest image needs to build include in the filesystem overlay.
First, build the stvmm-guest configuration and copy stimage.zip, stimage.json and
stimage.zip.endorsement to overlays/vanilla/var/lib/stvmm Then build the
hypervisor image.

When building the guest make sure the 'ra' command is in the path. The
hypervisor is booted in qemu with the boot-stvmm target.


## Packages to be installed

Package names are read from 'pkgs/000base.pkglist' and 'pkgs/$FLAVOUR.pkglist'.

'pkgs/000base.pkglist' is required while 'pkgs/$FLAVOUR.pkglist' is optional.


## Filesystem overlay

If a directory 'overlays/$FLAVOUR' exists it is copied recursively to
the target file system.


## Final adjustments of the target filesystem

The following adjustments are done to the target filesystem, in the
order listed:

1. If the file 'scripts/setup.sh' exists and is executable it is invoked.

1. If the file 'scripts/setup-in-chroot.sh' exists and is executable
it is invoked chrooted into the file system of the OS image.

1. The root password is set, either from the file 'pw.root' if it
   exists or by reading stdin.

1. If the file 'scripts/cleanup.sh' exists and is executable it is
   invoked.
