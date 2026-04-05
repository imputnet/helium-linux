FROM debian:trixie-slim

ARG UID=1000
ARG GID=$UID

## Set deb to non-interactive mode and upgrade packages
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && export DEBIAN_FRONTEND=noninteractive
RUN apt -y update && apt -y upgrade

## Install system dependencies
RUN apt -y install binutils elfutils desktop-file-utils dpkg dpkg-dev fakeroot file git imagemagick wget xz-utils pv curl jq python3 zsync gnupg perl make liblocale-gettext-perl

## Install Chromium runtime libraries for debbuild resolution
RUN apt -y install --no-install-recommends \
    libasound2t64 libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 \
    libcairo2 libcups2t64 libdbus-1-3 libdrm2 libexpat1 libgbm1 \
    libglib2.0-0t64 libgtk-3-0t64 libnspr4 libnss3 libpango-1.0-0 \
    libudev1 libvulkan1 libx11-6 libxcb1 libxcomposite1 libxdamage1 \
    libxext6 libxfixes3 libxkbcommon0 libxrandr2

## Install debbuild for .deb packaging
RUN git clone --depth 1 --branch 24.12.0 https://github.com/debbuild/debbuild.git /tmp/debbuild \
    && cd /tmp/debbuild \
    && git checkout 65c140bf902aa4860709a899a0f197fd7aa05e56 \
    && perl configure --prefix=/usr \
    && make \
    && make install \
    && rm -rf /tmp/debbuild

RUN curl -s https://api.github.com/repos/AppImage/appimagetool/releases/tags/1.9.0 \
    | jq -r '.assets[].browser_download_url' \
    | grep $(uname -m) \
    | xargs curl -Lo /usr/bin/appimagetool-$(uname -m).AppImage

RUN cat <<EOF | (cd /usr/bin; sha256sum -c --strict --ignore-missing)
    46fdd785094c7f6e545b61afcfb0f3d98d8eab243f644b4b17698c01d06083d1  appimagetool-x86_64.AppImage
    04f45ea45b5aa07bb2b071aed9dbf7a5185d3953b11b47358c1311f11ea94a96  appimagetool-aarch64.AppImage
    2148af7e848c8f1f8b079045907828874fc14ec7f593426b6d0a95c759174de4  appimagetool-i686.AppImage
    848f3bcccc7e08da1414156e78a59da76fcb5a8c98d3d4e9ef8ab557e5892ad5  appimagetool-armhf.AppImage
EOF

RUN mv /usr/bin/appimagetool-$(uname -m).AppImage /usr/bin/appimagetool

RUN chmod +x /usr/bin/appimagetool

# create builder user
RUN groupadd -g ${GID} builder && useradd -d /home/builder -g ${GID} -u ${UID} -m builder

USER builder

## Create and set WORKDIR to mount in docker build
WORKDIR /repo
