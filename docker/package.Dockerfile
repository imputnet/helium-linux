FROM debian:trixie-slim

## Set deb to non-interactive mode and upgrade packages
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && export DEBIAN_FRONTEND=noninteractive
RUN apt -y update && apt -y upgrade

## Install system dependencies
RUN apt -y install binutils desktop-file-utils dpkg file imagemagick wget xz-utils pv curl jq python3

# FIXME: it would be better if we could find some way to
# pin this to a fixed version, instead of blindly downloading
# some random backdoorable binary.
RUN curl -s https://api.github.com/repos/AppImage/appimagetool/releases/latest \
    | jq -r '.assets[].browser_download_url' \
    | grep $(uname -m) \
    | xargs curl -Lo /usr/bin/appimagetool
RUN chmod +x /usr/bin/appimagetool

# create builder user
RUN groupadd -g 1000 builder && useradd -d /home/builder -g 1000 -u 1000 -m builder

USER builder

## Create and set WORKDIR to mount in docker build
WORKDIR /repo
