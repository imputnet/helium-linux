#!/bin/bash
set -euxo pipefail

_base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd ../.. && pwd)"
_cache_tar="${_base_dir}/.github/cache/build-cache-$ARCH.tar.zst"

cd "$_base_dir"

[ -d "build" ] || exit 1

mkdir -p "$(dirname "$_cache_tar")"
rm -rf "build/download_cache"
tar -cf - "build" | zstd -f -T0 -3 -o "${_cache_tar}"
