#!/bin/bash
set -euo pipefail

_current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
_root_dir="$(cd "$_current_dir/.." && pwd)"
_build_dir="$_root_dir/build"
_release_dir="$_build_dir/release"
_app_dir="$_release_dir/Helium.AppDir"

_app_name="helium"
_version=$(python3 "$_root_dir/helium-chromium/utils/helium_version.py" \
                   --tree "$_root_dir/helium-chromium" \
                   --platform-tree "$_root_dir" \
                   --print)

_arch=$(cat "$_build_dir/src/out/Default/args.gn" \
                | grep ^target_cpu \
                | tail -1 \
                | sed 's/.*=//' \
                | cut -d'"' -f2)

if [ "$_arch" = "x64" ]; then
    _arch="x86_64"
fi

case "$_arch" in
    x86_64)
        _deb_arch="amd64"
        _rpm_arch="x86_64"
        ;;
    arm64)
        _deb_arch="arm64"
        _rpm_arch="aarch64"
        ;;
    *)
        _deb_arch="$_arch"
        _rpm_arch="$_arch"
        ;;
esac

_release_name="$_app_name-$_version-$_arch"
_update_info="gh-releases-zsync|imputnet|helium-linux|latest|$_app_name-*-$_arch.AppImage.zsync"
_tarball_name="${_release_name}_linux"
_tarball_dir="$_release_dir/$_tarball_name"

_files="helium
chrome_100_percent.pak
chrome_200_percent.pak
helium_crashpad_handler
chromedriver
icudtl.dat
libEGL.so
libGLESv2.so
libqt5_shim.so
libqt6_shim.so
libvk_swiftshader.so
libvulkan.so.1
locales/
product_logo_256.png
resources.pak
v8_context_snapshot.bin
vk_swiftshader_icd.json
xdg-mime
xdg-settings"

_deb_deps=(
  libnss3
  libnspr4
  libgtk-3-0
  libxss1
  libasound2
  libx11-xcb1
  libdrm2
  libgbm1
  libxdamage1
  libxcomposite1
  libxcursor1
  libxrandr2
  libxi6
  libatk-bridge2.0-0
  libatspi2.0-0
  libxcb-dri3-0
  libxcb-dri2-0
  libxcb-present0
  libxkbcommon0
  libxshmfence1
  ca-certificates
  fonts-liberation
)

_rpm_deps=(
  nss
  nspr
  gtk3
  libXScrnSaver
  libX11-xcb
  libdrm
  mesa-libgbm
  libXdamage
  libXcomposite
  libXcursor
  libXrandr
  libXi
  at-spi2-atk
  at-spi2-core
  libxcb
  libxkbcommon
  libxshmfence
  ca-certificates
  liberation-fonts
  alsa-lib
)

echo "copying release files and creating $_tarball_name.tar.xz"

rm -rf "$_tarball_dir"
mkdir -p "$_tarball_dir"

for file in $_files; do
    cp -r "$_build_dir/src/out/Default/$file" "$_tarball_dir" &
done

cp "$_root_dir/package/helium.desktop" "$_tarball_dir"
cp "$_root_dir/package/helium-wrapper.sh" "$_tarball_dir/helium-wrapper"

wait
(cd "$_tarball_dir" && ln -sf helium chrome)

if command -v eu-strip >/dev/null 2>&1; then
    _strip_cmd=eu-strip
else
    _strip_cmd="strip --strip-unneeded"
fi

find "$_tarball_dir" -type f -exec file {} + \
    | awk -F: '/ELF/ {print $1}' \
    | xargs $_strip_cmd

_size="$(du -sk "$_tarball_dir" | cut -f1)"

pushd "$_release_dir"

TAR_PATH="$_release_dir/$_tarball_name.tar.xz"
tar vcf - "$_tarball_name" \
    | pv -s"${_size}k" \
    | xz -e9 > "$TAR_PATH" &

# create AppImage
rm -rf "$_app_dir"
mkdir -p "$_app_dir/opt/helium/" "$_app_dir/usr/share/icons/hicolor/256x256/apps/"
cp -r "$_tarball_dir"/* "$_app_dir/opt/helium/"
cp "$_root_dir/package/helium.desktop" "$_app_dir"

cp "$_root_dir/package/helium-wrapper-appimage.sh" "$_app_dir/AppRun"

for out in "$_app_dir/helium.png" "${_app_dir}/usr/share/icons/hicolor/256x256/apps/helium.png"; do
    cp "${_app_dir}/opt/helium/product_logo_256.png" "$out"
done

export APPIMAGETOOL_APP_NAME="Helium"
export VERSION="$_version"

# check whether CI GPG secrets are available
if [[ -n "${GPG_PRIVATE_KEY:-}" && -n "${GPG_PASSPHRASE:-}" ]]; then
    echo "$GPG_PRIVATE_KEY" | gpg --batch --import --passphrase "$GPG_PASSPHRASE"
    export APPIMAGETOOL_SIGN_PASSPHRASE="$GPG_PASSPHRASE"
fi

appimagetool \
    -u "$_update_info" \
    "$_app_dir" \
    "$_release_name.AppImage" "$@" &


build_fpm_pkg() {
  local _target=$1
  local _deps_flag=()
  if [[ "$_target" == "deb" ]]; then
    for d in "${_deb_deps[@]}"; do _deps_flag+=("-d" "$d"); done
  else
    for d in "${_rpm_deps[@]}"; do _deps_flag+=("-d" "$d"); done
  fi

  local _stage_dir=$(mktemp -d)
  local _pkg_name="helium"
  local _install_path="/usr/lib/$_pkg_name"

  mkdir -p "$_stage_dir$_install_path"
  cp -r "$_tarball_dir"/* "$_stage_dir$_install_path/"

  # Symlink binary
  mkdir -p "$_stage_dir/usr/bin"
  ln -sf "$_install_path/helium" "$_stage_dir/usr/bin/helium"

  # Desktop file
  mkdir -p "$_stage_dir/usr/share/applications"
  cp "$_root_dir/package/helium.desktop" "$_stage_dir/usr/share/applications/$_pkg_name.desktop"

  # Icon
  mkdir -p "$_stage_dir/usr/share/icons/hicolor/256x256/apps"
  cp "$_tarball_dir/product_logo_256.png" "$_stage_dir/usr/share/icons/hicolor/256x256/apps/helium.png"

  local _fpm_arch
  if [[ "$_target" == "deb" ]]; then
      _fpm_arch="$_deb_arch"
  else
      _fpm_arch="$_rpm_arch"
  fi

  local _output_pkg="${_release_dir}/${_pkg_name}_${_version}_${_target}.pkg"
  
  fpm -s dir -t "$_target" \
    -n "$_pkg_name" \
    -v "$_version" \
    --architecture "$_fpm_arch" \
    --url "https://helium.computer" \
    --maintainer "Helium" \
    --description "Helium browser" \
    --provides "$_pkg_name" \
    --replaces "$_pkg_name" \
    "${_deps_flag[@]}" \
    -C "$_stage_dir" \
    --prefix / \
    --package "$_output_pkg" \
    .

  # Rename to friendly extension.
  if [[ "$_target" == "deb" ]]; then
    local _final_pkg="${_release_dir}/${_pkg_name}-${_version}-${_deb_arch}.deb"
    mv "$_output_pkg" "$_final_pkg"
  else
    local _final_pkg="${_release_dir}/${_pkg_name}-${_version}-1.${_rpm_arch}.rpm"
    mv "$_output_pkg" "$_final_pkg"
  fi

  rm -rf "$_stage_dir"
}

if command -v fpm >/dev/null 2>&1; then
    echo "Building .deb package..."
    build_fpm_pkg deb &
    echo "Building .rpm package..."
    build_fpm_pkg rpm &
else
    echo "fpm not found, skipping .deb and .rpm generation"
fi

popd
wait

if [ -n "${SIGN_TARBALL:-}" ]; then
    gpg --detach-sign --passphrase "$GPG_PASSPHRASE" \
        --output "$TAR_PATH.asc" "$TAR_PATH"
fi

rm -rf "$_tarball_dir" "$_app_dir"
