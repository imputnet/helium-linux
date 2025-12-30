#!/bin/sh
# Copyright 2025 The Helium Authors
# You can use, redistribute, and/or modify this source code under
# the terms of the GPL-3.0 license that can be found in the LICENSE file.

# Replace when packaging, so that we can easily determine which
# distro the user is using if they open a bug report.
export CHROME_VERSION_EXTRA="custom"

# Let the wrapped binary know that it has been run through the wrapper.
CHROME_WRAPPER="$(readlink -f "$0")"
HERE="$(dirname "$CHROME_WRAPPER")"

export CHROME_WRAPPER
export LD_LIBRARY_PATH="$HERE:$HERE/lib:$HERE/lib.target${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

exec "$HERE/chrome" "$@"
