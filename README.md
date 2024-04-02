# System Transparency OS images

This repository contains a set of shell scripts and an example
Makefile for assembling System Transparency OS images and testing them
in a virtual machine using qemu and KVM.

OS images are also known as OS packages or ospkg's.

WARNING: The way you as a user interact with these tools **will** change!
See the [interface][#Interface] section below for details.

NOTE: This repository is only able to build Debian images.

## System Transparency overview

In [System Transparency][], the boot loader [stboot][] loads a signed
OS image containing a Linux kernel, a kernel command line and an
initial ramdisk (aka initramfs or initrd). stboot then verifies the OS
image signature(s) and runs the kernel with the provided arguments and
initramfs.

TODO: talk about provisioning and host specific data

Once the OS image has been booted it configures itself to provide the
service it's meant for. How this is done is up to the operator of the
system (you). This repository contains an example configuration
setting up a local DNS resolver and a single network service on port
4711/tcp.

[System Transparency]: https://www.system-transparency.org/
[stboot]: https://git.glasklar.is/system-transparency/core/stboot

## Trying it out

### Building an OS image

To build an OS image, try running `make stimage`.

The example Makefile will try to run everything needed in order to
produce an ST image, output to build/stimage.{json,zip}.

You will need a go compiler and a long list of other tools to complete
the build. If you're on a system without `mmdebstrap`, installing
`podman` will be necessary. Building the initramfs using
`build-initramfs` and the STDATA filesystem image using `mkstdata.sh`
currently require `sudo` to root.

If you get tired of hunting down all the dependencies, `make
check-all-dependencies` will list all commands missing on your system
for doing everything in the example Makefile.


### Booting an OS image in a virtual machine

To boot your image, try running `make boot`.

This will first build an ISO with stboot as init and contain a default
config and ST root certificate.

It will then start a VM, using QEMU, booting the ISO.

## Configuring your own image

See config/example/README.md for an example of how to configure an OS image.

## User interface

The way users interact with the tools in this repository **will**
change. Both in the short perspective when we find out that we need
more functionality which isn't easily added while keeping the
interface compatible. But also in the longer perspective when we start
using [mkosi][] for building OS images.

mkosi will be helpful by wrapping distro specific tools like
`mmdebstrap`, `dnf --installroot` and `pacman`, and allow support for
all Linux distributions that mkosi knows about.

The reason for publishing this repository before it has a stable
interface is to give a hint of how OS images can be built while
waiting. For an example of how we build OS images for both test and
production use, see
https://git.glasklar.is/system-transparency/project/qa-images and
https://git.glasklar.is/glasklar/infra/images.

[mkosi]: https://github.com/systemd/mkosi
