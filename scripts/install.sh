#!/usr/bin/env bash
set -euo pipefail

ROXIDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/roxide"
SERVICE_DIR="${HOME}/.config/systemd/user"

echo "╔══════════════════════════════╗"
echo "║   ROXIDE Shell Installer     ║"
echo "╚══════════════════════════════╝"
echo ""

# Check deps
check_dep() {
    command -v "$1" &>/dev/null || { echo "✗ Missing: $1"; exit 1; }
    echo "✓ $1"
}

echo "Checking dependencies..."
check_dep cargo
check_dep quickshell
check_dep niri
echo ""

# Build Rust core
echo "Building ROXIDE core..."
cd "${ROXIDE_DIR}/core"
cargo build --release
echo "✓ Build complete"
echo ""

# Install binary
mkdir -p "${BIN_DIR}"
install -Dm755 "target/release/roxide" "${BIN_DIR}/roxide"
echo "✓ Installed binary → ${BIN_DIR}/roxide"

# Install QML config
mkdir -p "${CONFIG_DIR}"
cp -r "${ROXIDE_DIR}/quickshell" "${CONFIG_DIR}/"
echo "✓ Installed QML → ${CONFIG_DIR}/quickshell"

# Install systemd service
mkdir -p "${SERVICE_DIR}"
install -Dm644 "${ROXIDE_DIR}/distro/arch/roxide.service" "${SERVICE_DIR}/roxide.service"
echo "✓ Installed systemd unit"

# Enable service
systemctl --user daemon-reload
systemctl --user enable --now roxide.service
echo "✓ Service enabled and started"

echo ""
echo "Installation complete!"
echo ""
echo "Launch the shell:"
echo "  quickshell -p ${CONFIG_DIR}/quickshell"
echo ""
echo "Add to your niri config:"
echo '  spawn-at-startup "quickshell" "-p" "'"${CONFIG_DIR}/quickshell"'"'
echo ""
echo "Logs: journalctl --user -u roxide -f"
