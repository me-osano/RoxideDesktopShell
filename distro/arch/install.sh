#!/usr/bin/env bash
set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
QUICKSHELL_DIR="${INSTALL_PREFIX}/share/quickshell/roxide"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/RoxideDesktopShell"
SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

echo "╔══════════════════════════════════════╗"
echo "║   ROXIDE Desktop Shell Installer     ║"
echo "╚══════════════════════════════════════╝"
echo ""

check_dep() {
    command -v "$1" &>/dev/null || { echo "✗ Missing: $1"; exit 1; }
    echo "✓ $1"
}

echo "Checking dependencies..."
check_dep rustc
check_dep cargo
check_dep quickshell

echo "Building roxide-core..."
cd core
cargo build --release
cd ..

echo "Installing roxide binary..."
sudo install -Dm755 core/target/release/roxide "$INSTALL_PREFIX/bin/roxide"

echo "Installing Quickshell configuration..."
mkdir -p "$QUICKSHELL_DIR"
cp -r quickshell/* "$QUICKSHELL_DIR/"

echo "Installing systemd service..."
mkdir -p "$SYSTEMD_DIR"
cp assets/systemd/roxide.service "$SYSTEMD_DIR/"

echo ""
echo "Installation complete!"
echo ""
echo "To enable and start roxide:"
echo "  systemctl --user daemon-reload"
echo "  systemctl --user enable --now roxide.service"
echo ""
echo "To start Quickshell with roxide configuration:"
echo "  qs -c $QUICKSHELL_DIR"
echo ""
echo "Note: You may need to set QT_QML_IMPORT_PATH and QT_PLUGIN_PATH"
echo "      for Quickshell to find Qt modules. See README for details."