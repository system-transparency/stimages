System Transparency OS images

In System Transparency, [stboot][] loads a signed OS image containing
a kernel, an initramfs and a kernel command line. **stboot** then
verifies the signature(s) and runs the kernel with the provided
arguments and initramfs.

This repository contains instructions and code for assembling System
Transparency OS images.

[stboot]: https://git.glasklar.is/system-transparency/core/stboot

----

For playing around, try running `make` without arguments.

The file example.makefile will try to run everything needed in order
to produce an example ST image and write it to
build/stimage.{json,zip}.

You will need a go compiler and a long list of other tools installed
to complete the build. If you're on a system without mmdebstrap,
installing podman will be necessary.


To boot your image, try running `make boot`.

The building of stboot requires GOPATH to be set to point to a
directory where u-root, stboot and all their depencencies will be
installed. Try `export GOPATH=$PWD/go` if you're unsure about how to
deal with this.


----

TODO: add instructions on how to configure the image

