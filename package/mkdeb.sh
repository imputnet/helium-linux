#!/usr/bin/env bash
set -euxo pipefail

_current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
_root_dir="$(cd "$_current_dir/.." && pwd)"
_release_dir="$_root_dir/build/release"
_spec="$_root_dir/package/helium-bin.spec"
_metainfo_file="$_root_dir/package/net.imput.helium.metainfo.xml"

_version=$(python3 "$_root_dir/helium-chromium/utils/helium_version.py" \
                   --tree "$_root_dir/helium-chromium" \
                   --platform-tree "$_root_dir" \
                   --print)
_tarball="$(realpath "${1:-}")"

if ! [ -f "$_tarball" ]; then
    echo "usage: $0 <path to .tar.xz from release.sh" >&2
    exit 1
fi

_tarball_basename="$(basename "$_tarball")"
case "$_tarball_basename" in
    *x86_64*) _deb_arch="amd64" ;;
    *arm64*) _deb_arch="arm64" ;;
    *) exit 1;;
esac

_debbuild_dir=$(mktemp -d)
trap 'rm -rf "$_debbuild_dir"' EXIT

mkdir -p "$_debbuild_dir"/{BUILD,SOURCES,SPECS,DEBS}
ln -s "$_tarball" "$_metainfo_file" "$_debbuild_dir/SOURCES/"
cp "$_spec" "$_debbuild_dir/SPECS/"

# sanity check for shared libs
_tmpbin=$(mktemp)
trap 'rm -rf "$_debbuild_dir"; rm -f "$_tmpbin"' EXIT
tar -xOf "$_tarball" --strip-components=1 --wildcards '*/helium' > "$_tmpbin"
_missing="$(ldd "$_tmpbin" 2>&1 | grep 'not found' || true)"
rm -f "$_tmpbin"

if [ -n "$_missing" ]; then
    echo "error: unresolved shared libraries found:" >&2
    echo "$_missing" >&2
    exit 1
fi

debbuild \
    --define "_topdir $_debbuild_dir" \
    --define "debbuild 1" \
    --define "version $_version" \
    --define "_arch $_deb_arch" \
    --define "dist %{nil}" \
    -bb "$_debbuild_dir/SPECS/helium-bin.spec"

mkdir -p "$_release_dir"
mv "$_debbuild_dir"/DEBS/*/*.deb "$_release_dir/"
ls "$_release_dir"/*.deb
