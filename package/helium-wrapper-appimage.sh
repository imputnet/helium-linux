#!/bin/sh
# Copyright 2025 The Helium Authors
# You can use, redistribute, and/or modify this source code under
# the terms of the GPL-3.0 license that can be found in the LICENSE file.

# This is the script that runs when the Helium AppImage is launched.
# It will most likely not do anything useful outside of this.
THIS="$(readlink -f "${0}")"
HERE="$(dirname "${THIS}")"
export LD_LIBRARY_PATH="${HERE}/usr/lib:$LD_LIBRARY_PATH"
export CHROME_WRAPPER="${APPIMAGE:-$THIS}"
export CHROME_VERSION_EXTRA=appimage

AA_PROFILE_PATH=/etc/apparmor.d/helium-appimage
AA_SYSFS_USERNS_PATH=/proc/sys/kernel/apparmor_restrict_unprivileged_userns

has_command() {
    [ -x "$(command -v "$1")" ]
}

sudo_shim() {
    if [ "$(id -u)" = 0 ]; then
        (set -x; "$@")
    elif has_command pkexec; then
        (set -x; exec pkexec "$@")
    elif has_command sudo; then
        (set -x; exec sudo "$@")
    elif has_command su; then
        (set -x; exec su -c "$*")
    else
        return 1
    fi
}

needs_apparmor_bootstrap() {
    [ "$APPARMOR_BOOTSTRAPPED" != 1 ] \
        && [ -f $AA_SYSFS_USERNS_PATH ] \
        && [ 0 != "$(cat $AA_SYSFS_USERNS_PATH)" ] \
        && has_command aa-enabled \
        && [ "$(aa-enabled)" = Yes ] \
        && [ -d /etc/apparmor.d ] \
        && {
            ! [ -f "$AA_PROFILE_PATH" ] \
            || [ "$(print_apparmor_profile)" != "$(cat $AA_PROFILE_PATH)" ]
        };
}

has_apparmor_prereqs() {
    if [ -z "$APPIMAGE" ]; then
        echo "WARN: Skipping AppArmor bootstrap due to missing \$APPIMAGE path" >&2
        return 1
    fi

    if ! has_command apparmor_parser; then
        echo "WARN: Skipping AppArmor bootstrap due to missing apparmor_parser" >&2
        return 1
    fi
}

print_apparmor_profile() {
    APPIMAGE_ESC=$(echo "$APPIMAGE" | sed 's/"/\\"/g' | tr -d '\n')

    echo 'abi <abi/4.0>,'
    echo 'include <tunables/global>'
    echo
    echo 'profile helium-appimage "'"$APPIMAGE_ESC"'" flags=(default_allow) {'
    echo '  userns,'
    echo '  include if exists <local/helium-appimage>'
    echo '}'
}

if needs_apparmor_bootstrap && has_apparmor_prereqs; then
    echo "Helium has detected that your system uses AppArmor." >&2
    echo "Before Helium can run, it needs to create an AppArmor profile for itself." >&2
    echo "It will request to run commands as root. If you do not wish to do this, please exit." >&2

    print_apparmor_profile | sudo_shim tee "$AA_PROFILE_PATH" && \
        sudo_shim chmod 644 "$AA_PROFILE_PATH" && \
        sudo_shim apparmor_parser -r "$AA_PROFILE_PATH" && \
        # We need to re-exec here, because otherwise the
        # AppArmor profile will not apply.
        APPARMOR_BOOTSTRAPPED=1 exec "$APPIMAGE"
fi

"${HERE}"/opt/helium/chrome "$@"
