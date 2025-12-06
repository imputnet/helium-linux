#!/usr/bin/env bash
set -euo pipefail

REPO="imputnet/helium-linux"
API_LATEST="https://api.github.com/repos/${REPO}/releases/latest"
INSTALL_DIR="${HOME}/.local/helium"
BACKUP_DIR="${HOME}/.local/helium_backup"
DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Simple revert on failure: put backup back if we had renamed it
DID_RENAME=false
STARTED_INSTALL=false
on_err() {
  rc=$?
  echo "❌ ERROR: install failed (exit code $rc). Reverting..."
  if [ "${DID_RENAME}" = true ]; then
    rm -rf "$INSTALL_DIR" || true
    if [ -d "$BACKUP_DIR" ]; then
      mv "$BACKUP_DIR" "$INSTALL_DIR" || true
      echo "🛠️ Restored previous install."
    fi
  elif [ "${STARTED_INSTALL}" = true ]; then
    rm -rf "$INSTALL_DIR" || true
    echo "🧹 Removed incomplete install."
  fi
  exit $rc
}
trap 'on_err' ERR

echo "🚀 Welcome to Helium tarball installer!"
echo "😌 Please relax and wait for the installation to complete."
echo
sleep 1

# ensure Linux
if [ "$(uname -s)" != "Linux" ]; then
  echo "🖥️ This installer supports Linux only."
  exit 1
fi

# detect arch (match asset naming)
case "$(uname -m)" in
  x86_64) ARCH="x86_64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *)
    echo "⚠️ Unsupported architecture: $(uname -m)"
    exit 1
    ;;
esac
echo "🧩 Detected architecture: $ARCH"

# fetch latest release tag via GitHub API
if ! command -v jq >/dev/null 2>&1; then
  echo "🔧 jq is required to parse GitHub API. Please install jq and retry."
  exit 1
fi

echo "🔎 Fetching latest version info..."
version_tag="$(curl -sL "$API_LATEST" | jq -r .tag_name)"
if [ -z "${version_tag}" ] || [ "${version_tag}" = "null" ]; then
  echo "❗ Could not determine latest release tag from GitHub API."
  exit 1
fi
version_file="${version_tag#v}"

filename="helium-${version_file}-${ARCH}_linux.tar.xz"
download_url="https://github.com/${REPO}/releases/download/${version_tag}/${filename}"
out_file="$TMPDIR/$filename"

echo "⬇️ Downloading the latest package ($version_tag)..."
curl -L --progress-bar -o "$out_file" "$download_url"
if [ $? -eq 0 ]; then
    echo "✅ Download OK"
else
    echo "❌ Download failed. Curl not found or not installed"
    exit
fi

# Prepare temp extraction dir
mkdir -p "$TMPDIR/extract"

# If an existing install is present, rename it to backup
if [ -d "$BACKUP_DIR" ]; then
  rm -rf "$BACKUP_DIR"
fi
if [ -d "$INSTALL_DIR" ]; then
  echo "🔁 Backing up existing install -> $BACKUP_DIR"
  mv "$INSTALL_DIR" "$BACKUP_DIR"
  DID_RENAME=true
fi

# Create fresh install dir
mkdir -p "$INSTALL_DIR"
STARTED_INSTALL=true

# Extract archive into temp, then copy into install dir
echo "📦 Extracting archive..."
tar -xJf "$out_file" -C "$TMPDIR/extract" --strip-components=1

# Copy files into install dir
cp -a "$TMPDIR/extract"/. "$INSTALL_DIR"/

# Write desktop entry
mkdir -p "$DESKTOP_DIR"
desktop_file="${DESKTOP_DIR}/helium.desktop"
cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Name=Helium
GenericName=Web Browser
Comment=Access the Internet
Exec=${INSTALL_DIR}/chrome %U
TryExec=${INSTALL_DIR}/chrome
Icon=${INSTALL_DIR}/product_logo_256.png
StartupNotify=false
StartupWMClass=helium
Terminal=false
Type=Application
Categories=Network;WebBrowser;
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=Helium
Exec=${INSTALL_DIR}/chrome %U
TryExec=${INSTALL_DIR}/chrome
Icon=${INSTALL_DIR}/product_logo_256.png

[Desktop Action new-private-window]
Name=Helium
Exec=${INSTALL_DIR}/chrome --incognito %U
TryExec=${INSTALL_DIR}/chrome
Icon=${INSTALL_DIR}/product_logo_256.png

MimeType=x-scheme-handler/unknown;x-scheme-handler/about;application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;
EOF
chmod 644 "$desktop_file"

# Success: remove backup if it exists
if [ -d "$BACKUP_DIR" ]; then
  echo "🗑️ Successfully installed, removing backup directory"
  rm -rf "$BACKUP_DIR"
fi

echo
echo "📝 Created desktop entry successfully!"
echo "🎉 Installation is successful!"
echo "📂 Installed at: $INSTALL_DIR"
echo "🖇️ Desktop file: $desktop_file"
exit 0
