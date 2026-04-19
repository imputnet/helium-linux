# helium-linux
Linux builds, packaging, and development tooling for the
[Helium Browser](https://github.com/imputnet/helium).

## Downloads
Helium is available in multiple formats depending on your distribution.<br>
We offer builds for `x86_64/amd64` and `arm64/aarch64` platforms.

> [!NOTE]
> Packaging not listed here is not officially maintained and should be
> used with extreme caution.

### Fedora
1. Enable [Helium COPR](https://copr.fedorainfracloud.org/coprs/imput/helium/):
    ```bash
    sudo dnf copr enable imput/helium
    ```

1. Install Helium:
    ```bash
    sudo dnf install helium-bin
    ```

### Debian/Ubuntu
1. Add Helium's signing public key:
    ```bash
    curl -fsSL https://raw.githubusercontent.com/imputnet/helium-linux/main/pubkey.asc | sudo gpg --dearmor -o /usr/share/keyrings/helium.gpg
    ```

1. Add Helium's repo:
    ```bash
    echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/helium.gpg] https://pkg.helium.computer/deb stable main" | sudo tee /etc/apt/sources.list.d/helium.list
    ```
    For prerelease builds, replace `stable` with `prerelease`

1. Update apt lists and install Helium:
    ```bash
    sudo apt update && sudo apt install helium-bin
    ```

### AppImage and binary tarball
[Download the latest release on GitHub](https://github.com/imputnet/helium-linux/releases/latest)

### Flatpak/Flathub
We will not support Flatpak as long as it's impossible to package Chromium
without [breaking its sandbox](https://discuss.privacyguides.net/t/does-flatpak-weaken-chromium-firefoxs-sandbox/13373/7).
We recommend that you use AppImage if an official distro package isn't
available.

## Credits

### Depot
Big thank you to [Depot](https://depot.dev/) for sponsoring our runners,
which handle the Linux builds of Helium. Their high-performance infrastructure
lets us compile, package, and release new builds of Helium within hours,
not days.

### ungoogled-chromium
This repo uses some stuff that originally came from
[ungoogled-chromium-portablelinux](https://github.com/ungoogled-software/ungoogled-chromium-portablelinux)
before we fully remade it and forked it for Helium.

## Contributing
Before contributing to this repo, please read the guidelines in main repo's
[CONTRIBUTING.md](https://github.com/imputnet/helium/blob/main/CONTRIBUTING.md).

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
1. Create a Docker image of a Debian-based building environment with all
   required packages (llvm, nodejs and distro packages) included.
2. Run `scripts/build.sh` inside the Docker image to build Helium.

Running `scripts/build.sh` directly will not work unless you're running a
Debian-based distro and have all necessary dependencies installed. This repo is
designed to avoid having to configure the building environment on your Linux
installation.

### Packaging
After building, run `scripts/package.sh`. Alternatively, you can run
`package/docker-package.sh` to build inside a Docker image. Either of these
scripts will create `tar.xz` and `AppImage` files under `build/`.

If you would like to also generate a .deb file, you can set `MAKE_DEB=1` when
running the release script.

### Development
By default, the build script uses tarball. If you need to use a source tree
clone, you can run `scripts/docker-build.sh -c` instead. This may be useful if
a tarball for a release isn't available yet.

### Signature
AppImage builds (since [0.5.7.1](https://github.com/imputnet/helium-linux/releases/tag/0.5.7.1)),
binary tarballs (since [0.7.7.2](https://github.com/imputnet/helium-linux/releases/tag/0.7.7.2)),
and the .deb repository (since [0.10.7.1](https://github.com/imputnet/helium-linux/releases/tag/0.10.7.1))
are signed with the following key:

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
