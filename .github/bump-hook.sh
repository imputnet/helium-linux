#!/bin/bash
set -euxo pipefail

PLATFORM_DIR="$PWD"
HELIUM_DIR="$PLATFORM_DIR/helium-chromium"
SPEC="$PLATFORM_DIR/package/helium-bin.spec"

# version_after is exported by `bump-platform` action
sed -Ei "s/^(%define version ).*/\1$version_after/" "$SPEC"
git add -u "$SPEC"
