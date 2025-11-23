#!/bin/sh
# Copyright 2025 The Helium Authors
# You can use, redistribute, and/or modify this source code under
# the terms of the GPL-3.0 license that can be found in the LICENSE file.

THIS="$(readlink -f "${0}")"
HERE="$(dirname "${THIS}")"
export LD_LIBRARY_PATH="${HERE}/usr/lib:$LD_LIBRARY_PATH"
export CHROME_WRAPPER="${THIS}"
"${HERE}"/opt/helium/chrome "$@"
