%define version 0.7.9.1
%global debug_package %{nil}

Name:    helium-bin
Summary: Private, fast, and honest web browser
Version: %{version}
Release: 1%{?dist}
License: GPL-3.0
URL:     https://github.com/imputnet/helium-linux
Source0: https://github.com/imputnet/helium-linux/releases/download/%{version}/helium-%{version}-x86_64_linux.tar.xz
Source1: https://github.com/imputnet/helium-linux/releases/download/%{version}/helium-%{version}-arm64_linux.tar.xz

%description
Private, fast, and honest web browser based on Chromium

%prep
%ifarch x86_64
%setup -q -n helium-%{version}-x86_64_linux
%endif

%ifarch aarch64
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
         %{buildroot}%{_datadir}/icons/hicolor/256x256/apps

cp -a . %{heliumdir}

sed -Ei "s/(CHROME_VERSION_EXTRA=).*/\1rpm/" \
    %{heliumdir}/helium-wrapper

install -m 644 product_logo_256.png \
    %{buildroot}%{_datadir}/icons/hicolor/256x256/apps/helium.png

install -m 644 %{heliumdir}/helium.desktop \
    %{buildroot}%{_datadir}/applications/

ln -sf %{helium_base}/helium-wrapper \
    %{buildroot}%{_bindir}/helium

%files
%defattr(-,root,root,-)
%{helium_base}/
%{_bindir}/helium
%{_datadir}/applications/helium.desktop
%{_datadir}/icons/hicolor/256x256/apps/helium.png

%post
# Refresh icon cache and update desktop database
/usr/bin/update-desktop-database &> /dev/null || :
/bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null || :

%postun
# Refresh icon cache and update desktop database
/usr/bin/update-desktop-database &> /dev/null || :
if [ $1 -eq 0 ] ; then
    /bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null
    /usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :
fi

%posttrans
/usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :

%changelog
%autochangelog
