#!/bin/bash
set -euxo pipefail

_base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd ../.. && pwd)"
_cache_tar="$_base_dir/.github/cache/build-cache-$ARCH.tar.zst"

zstd -d -c "${_cache_tar}" | tar -xf - -C "${_base_dir}"

# we no longer need the tarball once it's
# extracted, so let's get rid of it
rm "${_cache_tar}"
