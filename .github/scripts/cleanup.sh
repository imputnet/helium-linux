#!/bin/bash
set -euxo pipefail

# disk space on free runners is limited, let's make some
# space while waiting for build tree extraction to finish
sudo rm -rf /usr/local/lib/android \
            /usr/local/.ghcup \
            /usr/lib/jvm \
            /usr/lib/google-cloud-sdk \
            /usr/lib/dotnet \
            /usr/share/swift
