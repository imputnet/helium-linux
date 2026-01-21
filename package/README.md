# Helium packaging guidelines

This document provides guidelines for packagers creating Helium packages
for various Linux distriutions and packaging systems. These guidelines
aim to ensure consistency across different package formats while
respecting distribution-specific conventions.

## Installation
- The installation prefix of Helium packages is not mandated by
  upstream. Note that on FHS-compliant distributions, Chromium-based
  browsers are typically installed into /opt or /usr/lib64.
- The primary executable should be a symbolic link to
  $prefix/helium-wrapper. On FHS-compliant distributions, it should
  be installed into `/usr/bin` or `/usr/local/bin`.

## Branding
- The primary executable name should be `helium`.
- The package name should be `helium` if available; `helium-browser`
  is acceptable otherwise. If the packaging system uses reverse-DNS
  notation as identifiers, the identifier should be `net.imput.helium`
  (all lowercase).
- If built from releases marked as "pre-release", the package name
  should have a `-prerelease` (preferred), `-pre` or `-beta` suffix.
- If built from GitHub-hosted binaries, the package name should have a
  `-bin` suffix.
- If installing the desktop file, it should be named `helium.desktop`
   (or `net.imput.helium.desktop` on systems preferring reverse-DNS
    naming).
- If installing icons, the icon name should be `helium`
  (or `net.imput.helium`).

## Versioning
- Package versions should match the upstream version number.
- Package versions may include a package revision suffix (e.g. `-1` in
  `0.8.7.1-1`) for the convenience of package development and
  maintenance.

## Tweaks
- Packages should not add environment-specific flags by default,
  such as enabling or disabling features via `--enable-features`
  or `--disable-features`.
- Packages should replace the `CHROME_VERSION_EXTRA` envvar with their
  distribution name (e.g. `Arch Linux`) or method of distribution
  (e.g. `rpm`) to assist with easier bug report handling.

## Security
- Packages MUST NOT add default arguments that weaken the security of
  Helium, including but not limited to `--no-sandbox`.
- Packagers are encouraged to provide MAC security profiles where
  applicable for enhanced security.
