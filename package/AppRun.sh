#!/bin/sh
THIS="$(readlink -f "${0}")"
HERE="$(dirname "${THIS}")"
export LD_LIBRARY_PATH="${HERE}/usr/lib:$LD_LIBRARY_PATH"
export CHROME_WRAPPER="${THIS}"
"${HERE}"/opt/helium/chrome "$@"
