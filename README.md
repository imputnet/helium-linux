# helium-linux
Portable Linux (`.AppImage`) packaging for [Helium](https://github.com/imputnet/helium).

## Credits
This repo is based on
[ungoogled-chromium-portablelinux](https://github.com/ungoogled-software/ungoogled-chromium-portablelinux)
and modified for Helium. Huge shout-out to everyone behind ungoogled-chromium,
they made working with Chromium infinitely easier.

Big thank you to [Depot](https://depot.dev/) for sponsoring our runners, which handle the Linux
builds of Helium. Their high-performance infrastructure lets us compile, package, and release
new builds of Helium within hours, not days.

## License
All code, patches, modified portions of imported code or patches, and
any other content that is unique to Helium and not imported from other
repositories is licensed under GPL-3.0. See [LICENSE](LICENSE).

Any content imported from other projects retains its original license (for
example, any original unmodified code imported from ungoogled-chromium remains
licensed under their [BSD 3-Clause license](LICENSE.ungoogled_chromium)).

## Building
To build the binary, run `scripts/docker-build.sh` from the repo root.

The `scripts/docker-build.sh` script will:
1. Create a Docker image of a Debian-based building environment with all required packages (llvm, nodejs and distro packages) included.
2. Run `scripts/build.sh` inside the Docker image to build Helium.

Running `scripts/build.sh` directly will not work unless you're running a Debian-based distro and have all necessary dependencies installed. This repo is designed to avoid having to configure the building environment on your Linux installation.

### Packaging
After building, run `scripts/package.sh`. Alternatively, you can run `package/docker-package.sh` to build inside a Docker image. If you would like to sign the resulting AppImage, you can pass the `--sign` argument.

Either of these scripts will create `tar.xz` and `AppImage` files under `build/`.

### Development
By default, the build script uses tarball. If you need to use a source tree clone, you can run `scripts/docker-build.sh -c` instead. This may be useful if a tarball for a release isn't available yet.

### Signature
As of [0.5.7.1](https://github.com/imputnet/helium-linux/releases/tag/0.5.7.1), AppImage builds are signed with the following key:
```
-----BEGIN PGP PUBLIC KEY BLOCK-----
Comment: BE67 7C19 89D3 5EAB 2C5F  26C9 3516 01AD 01D6 378E
Comment: Helium signing key (https://helium.computer/)

xjMEaOqhEBYJKwYBBAHaRw8BAQdA+0OK9OgI98hQGR0ZI5aVuXxdeDU+6eyLiKhH
4pwAaH7NQEhlbGl1bSBzaWduaW5nIGtleSAoaHR0cHM6Ly9oZWxpdW0uY29tcHV0
ZXIvKSA8aGVsaXVtQGltcHV0Lm5ldD7CmQQTFgoAQRYhBL5nfBmJ016rLF8myTUW
Aa0B1jeOBQJo6qEQAhsDBQkFo5qABQsJCAcCAiICBhUKCQgLAgQWAgMBAh4HAheA
AAoJEDUWAa0B1jeO31AA/0w52qczu5T4w0miS3up03c4uIJtdw2MfHFLIEAQN7T2
AP9ZI9ozR7C2/isB0GLeQM6o10DGiXGNA0T2kmNEJqIXC844BGjqoRASCisGAQQB
l1UBBQEBB0AoNTUK0xOCCMLTWO1Nvhe9el/bNuyTyMmincD7hXu5JwMBCAfCfgQY
FgoAJhYhBL5nfBmJ016rLF8myTUWAa0B1jeOBQJo6qEQAhsMBQkFo5qAAAoJEDUW
Aa0B1jeOLYEA/ReQcxHx9axm3rYYad+1XeQQyiIPCjclCVMyeAXqS5XOAP0RBc9/
md8JlXqOCGwmHuOk3VVkR5EjCgm2KJ8hqdhwBA==
=Chk7
-----END PGP PUBLIC KEY BLOCK-----
```
