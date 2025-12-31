#!/bin/bash

set -euxo pipefail

PLATFORM_DIR="$PWD"
HELIUM_DIR="$PLATFORM_DIR/helium-chromium"
SPEC="$PLATFORM_DIR/package/helium-bin.spec"

VERSION=$("$HELIUM_DIR/utils/helium_version.py" \
            --tree "$HELIUM_DIR" \
            --platform-tree "$PLATFORM_DIR" \
            --print)

sed -Ei "s/^(%define version ).*/\1$version_after/" "$SPEC"
git add -u "$SPEC"
