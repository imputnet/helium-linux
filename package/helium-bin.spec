%define version 0.11.7.1
%global debug_package %{nil}

Name:    helium-bin
Summary: Private, fast, and honest web browser
Version: %{version}
Release: 1%{?dist}
Group:   web
License: GPL-3.0
URL:     https://github.com/imputnet/helium-linux
Source0: https://github.com/imputnet/helium-linux/releases/download/%{version}/helium-%{version}-x86_64_linux.tar.xz
Source1: https://github.com/imputnet/helium-linux/releases/download/%{version}/helium-%{version}-arm64_linux.tar.xz
Source2: net.imput.helium.metainfo.xml

%if 0%{?debbuild}
Packager: imput <helium@imput.net>
Provides: www-browser
%endif

# Based on chrome/installer/linux/{debian,rpm}/additional_deps
# We do not recommend libgtk* because we don't use it by default.
# If the user wants GTK, they can install the relevant lib
# (and they already likely have them installed by default on a desktop install anyways).
Recommends: ca-certificates, xdg-utils
%if 0%{?debbuild}
Recommends: fonts-liberation, libvulkan1
%else
Recommends: liberation-fonts, vulkan-loader
%endif

%description
Private, fast, and honest web browser based on Chromium

%prep
%ifarch x86_64 amd64
%setup -q -n helium-%{version}-x86_64_linux
%endif

%ifarch aarch64 arm64
%setup -q -T -b 1 -n helium-%{version}-arm64_linux
%endif

%build
# We are using prebuilt binaries

%install
%define helium_base /opt/helium
%define heliumdir %{buildroot}%{helium_base}

mkdir -p %{heliumdir} \
         %{buildroot}%{_bindir} \
         %{buildroot}%{_datadir}/applications \
         %{buildroot}%{_datadir}/metainfo \
         %{buildroot}%{_datadir}/icons/hicolor/256x256/apps

cp -a . %{heliumdir}

%if 0%{?debbuild}
sed -Ei "s/(CHROME_VERSION_EXTRA=).*/\1deb/" \
    %{heliumdir}/helium-wrapper
%else
sed -Ei "s/(CHROME_VERSION_EXTRA=).*/\1rpm/" \
    %{heliumdir}/helium-wrapper
%endif

install -m 644 product_logo_256.png \
    %{buildroot}%{_datadir}/icons/hicolor/256x256/apps/helium.png

install -m 644 %{heliumdir}/helium.desktop \
    %{buildroot}%{_datadir}/applications/

install -m 644 %{SOURCE2} \
    %{buildroot}%{_datadir}/metainfo/net.imput.helium.metainfo.xml

ln -sf %{helium_base}/helium-wrapper \
    %{buildroot}%{_bindir}/helium

%files
%defattr(-,root,root,-)
%{helium_base}/
%{_bindir}/helium
%{_datadir}/applications/helium.desktop
%{_datadir}/metainfo/net.imput.helium.metainfo.xml
%{_datadir}/icons/hicolor/256x256/apps/helium.png

%post
# Refresh icon cache and update desktop database
/usr/bin/update-desktop-database > /dev/null 2>&1 || :
/bin/touch --no-create %{_datadir}/icons/hicolor > /dev/null 2>&1 || :

if command -v apparmor_parser > /dev/null 2>&1 && [ -d /etc/apparmor.d ]; then
    cp %{helium_base}/apparmor.cfg /etc/apparmor.d/helium-bin
    apparmor_parser -r -W -T /etc/apparmor.d/helium-bin || :
fi

%postun
# Refresh icon cache and update desktop database
/usr/bin/update-desktop-database > /dev/null 2>&1 || :
case "$1" in
    0|remove|purge)
        /bin/touch --no-create %{_datadir}/icons/hicolor > /dev/null 2>&1
        /usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor > /dev/null 2>&1 || :

        if [ -f /etc/apparmor.d/helium-bin ]; then
            if command -v apparmor_parser > /dev/null 2>&1; then
                apparmor_parser -R /etc/apparmor.d/helium-bin || :
            fi
            rm -f /etc/apparmor.d/helium-bin
        fi
        ;;
esac

%posttrans
/usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor > /dev/null 2>&1 || :

%changelog
%if "%{_vendor}" != "debbuild"
%autochangelog
%endif
