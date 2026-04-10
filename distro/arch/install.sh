#!/usr/bin/env bash
set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rustiq"
SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

echo "Installing rustiq-shell..."

if ! command -v rustc &> /dev/null; then
    echo "Error: Rust is not installed."
    echo "Install via: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi

echo "Building rustiq-core..."
cd core
cargo build --release
cd ..

echo "Installing rustiq binary..."
sudo install -Dm755 core/target/release/rustiq "$INSTALL_PREFIX/bin/rustiq"

echo "Installing Quickshell configuration..."
mkdir -p "$CONFIG_DIR"
cp -r quickshell/* "$CONFIG_DIR/"

echo "Installing systemd service..."
mkdir -p "$SYSTEMD_DIR"
cp distro/arch/rustiq.service "$SYSTEMD_DIR/"

echo ""
echo "Installation complete!"
echo ""
echo "To enable and start rustiq:"
echo "  systemctl --user daemon-reload"
echo "  systemctl --user enable --now rustiq.service"
echo ""
echo "To start Quickshell with rustiq configuration:"
echo "  quickshell -c $CONFIG_DIR"
echo ""
echo "Note: You may need to set QT_QML_IMPORT_PATH and QT_PLUGIN_PATH"
echo "      for Quickshell to find Qt modules. See README for details."