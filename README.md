# System Transparency OS images

This repository contains a set of shell scripts and an example
Makefile for assembling System Transparency OS images and testing them
in a virtual machine using qemu and KVM.

OS images are also known as OS packages or ospkg's.

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

To build an OS image, try running `make` without any arguments.

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

This will build stboot with a default config and ST root certificate.

Building stboot using `contrib/stboot/build-stboot` requires GOPATH to
be set to a directory where u-root, stboot and all go depencencies
will be installed. Setting GOPATH to $PWD/go is a reasonable choice if
you're unsure about how to deal with this.

## Configuring your own image

TODO: add instructions on how to configure an image
