#!/bin/bash
set -euxo pipefail

PLATFORM_DIR="$PWD"
HELIUM_DIR="$PLATFORM_DIR/helium-chromium"
SPEC="$PLATFORM_DIR/package/helium-bin.spec"
METAINFO="$PLATFORM_DIR/package/metainfo/net.imput.helium.metainfo.xml"

# version_after is exported by `bump-platform` action
sed -Ei "s/^(%define version ).*/\1$version_after/" "$SPEC"

# Update AppStream metainfo.xml with new release version and date
RELEASE_DATE=$(date +%Y-%m-%d)
# Update the first release entry with new version and date
sed -Ei "0,/<release version=\"[^\"]*\" date=\"[^\"]*\" \/>/s/<release version=\"[^\"]*\" date=\"[^\"]*\" \/>/<release version=\"$version_after\" date=\"$RELEASE_DATE\" \/>/" "$METAINFO"

git add -u "$SPEC" "$METAINFO"
