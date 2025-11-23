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

_release_name="$_app_name-$_version-$_arch"
_update_info="gh-releases-zsync|imputnet|helium-linux|latest|$_app_name-*-$_arch.AppImage.zsync"
_tarball_name="${_release_name}_linux"
_tarball_dir="$_release_dir/$_tarball_name"

_files="chrome
chrome_100_percent.pak
chrome_200_percent.pak
chrome_crashpad_handler
chromedriver
chrome-wrapper
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

echo "copying release files and creating $_tarball_name.tar.xz"

rm -rf "$_tarball_dir"
mkdir -p "$_tarball_dir"

for file in $_files; do
    cp -r "$_build_dir/src/out/Default/$file" "$_tarball_dir" &
done

cp "$_root_dir/package/helium.desktop" "$_tarball_dir"

wait

_size="$(du -sk "$_tarball_dir" | cut -f1)"

pushd "$_release_dir"

tar vcf - "$_tarball_name" \
    | pv -s"${_size}k" \
    | xz -e9 > "$_release_dir/$_tarball_name.tar.xz" &

# create AppImage
rm -rf "$_app_dir"
mkdir -p "$_app_dir/opt/helium/" "$_app_dir/usr/share/icons/hicolor/256x256/apps/"
cp -r "$_tarball_dir"/* "$_app_dir/opt/helium/"
cp "$_root_dir/package/helium.desktop" "$_app_dir"
sed -i -e 's|Exec=chromium|Exec=AppRun|g' "$_app_dir/helium.desktop"

cp "$_root_dir/package/AppRun.sh" "$_app_dir/AppRun"

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
popd
wait

rm -rf "$_tarball_dir" "$_app_dir"
