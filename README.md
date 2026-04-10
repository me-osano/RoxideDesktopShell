# ROXIDEDESKTOPSHELL

> A handcrafted Wayland desktop shell for [niri](https://github.com/YaLTeR/niri), built with Quickshell/QML and a Rust backend.

```
  
  ██████╗  ██████╗ ██╗  ██╗██╗██████╗  ███████╗
  ██╔══██╗██╔═══██║╚██╗██╔╝██║██╔═══██╗██╔════╝
  ██████╔╝██║   ██║ ╚███╔╝ ██║██║   ██║█████╗
  ██╔══██╗██║   ██║ ██╔██╗ ██║██║   ██║██╔══╝
  ██║  ██║╚██████╔╝██╔╝ ██╗██║██████╔═╝███████╗
  ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝  ╚══════╝
  
```

## Architecture

```
RoxideDesktopShell/
├── core/         # Rust daemon — IPC, sysmon, search, weather, niri IPC
└── quickshell/   # QML shell — bar, launcher, widgets, notifications
```

The Rust core runs as a single systemd user daemon (`roxide.service`).
Quickshell connects to it over a Unix socket at `$XDG_RUNTIME_DIR/roxide.sock`.

## Features

- **Bar** — workspace switcher, window title, tray, clock, system stats
- **Launcher** — app search, file search (tantivy-indexed), calculator
- **Widgets** — CPU/RAM/network, weather, media controls, clipboard
- **Notifications** — D-Bus org.freedesktop.Notifications server
- **OSD** — volume/brightness overlays
- **Greeter** — greetd greeter (pure QML)
- **Theme** — Catppuccin Mocha throughout

## Prerequisites

### Runtime Dependencies

| Component | Description | Required |
|-----------|-------------|----------|
| `niri` | Wayland compositor | Yes |
| `quickshell` | QML shell framework | Yes |
| `pipewire` / `wireplumber` | Audio | Yes |
| `networkmanager` | Network management | Yes |
| `greetd` | Display manager (for greeter) | Optional |
| `upower` | Battery monitoring | Optional |
| `bluez` | Bluetooth support | Optional |

### Build Dependencies

- `rust` 1.75+
- `cargo`
- `qt6` / `qt6-declarative`
- `pkgconf`
- `openssl` (development headers)

---

## Installation

### Nix Flake (Recommended for NixOS)

```nix
{
  inputs.roxide-desktop-shell.url = "github:me-osano/RoxideDesktopShell";
  imports = [ inputs.roxide-desktop-shell.homeModules.default ];
  programs.roxide-desktop-shell.enable = true;
}
```

Or for standalone testing:

```bash
# Enter dev shell with all dependencies
nix develop

# Build the package
nix build

# Run the shell
./result/bin/roxide -c ./quickshell
```

---

### Arch Linux

#### Option 1: PKGBUILD (Stable)

```bash
# Clone the repository
git clone https://github.com/me-osano/RoxideDesktopShell.git
cd RoxideDesktopShell

# Build and install
makepkg -si

# Or install without confirmation
makepkg -si --noconfirm
```

#### Option 2: PKGBUILD-git (Development)

```bash
# Add to AUR helper (e.g., yay, aurman)
yay -S RoxideDesktopShell-git

# Or build manually
git clone https://github.com/me-osano/RoxideDesktopShell.git
cd RoxideDesktopShell/distro/arch
makepkg -si
```

#### Option 3: Manual Build

```bash
git clone https://github.com/me-osano/RoxideDesktopShell.git
cd RoxideDesktopShell

# Run the install script
chmod +x distro/arch/install.sh
sudo ./distro/arch/install.sh
```

#### Option 4: Quick Install (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/me-osano/RoxideDesktopShell/master/distro/arch/install.sh | sh
```

**Post-installation (Arch):**

```bash
# Reload systemd
systemctl --user daemon-reload

# Enable and start the daemon
systemctl --user enable --now roxide.service

# Start quickshell with roxide config
quickshell -c ~/.config/roxide
```

---

## Configuration

### Qt Environment Variables

Quickshell requires proper Qt paths. Add to your shell profile:

```bash
# For system Qt (adjust paths for your distribution)
export QT_QML_IMPORT_PATH="${QT_QML_IMPORT_PATH:-}:/usr/lib/qt6/qml"
export QT_PLUGIN_PATH="${QT_PLUGIN_PATH:-}:/usr/lib/qt6/plugins"

# For locally built Qt (Nix)
export QT_QML_IMPORT_PATH="${NIXPKGS_QT6_QML_IMPORT_PATH}"
export QT_PLUGIN_PATH="${QT_PLUGIN_PATH}"
```

### Log Level

Set via environment variable:

```bash
export ROXIDE_LOG=debug  # debug, info, warn, error
```

### Alternative Config Location

```bash
roxide -c /path/to/config daemon
quickshell -c /path/to/config
```

---

## Usage

### CLI Commands

```bash
roxide status           # Daemon health check
roxide sysmon           # System monitoring snapshot
roxide search "query"   # File search
roxide weather          # Current weather
roxide niri workspaces  # Workspace list
roxide niri windows     # Window list
```

### Systemd Service

```bash
# Enable at login
systemctl --user enable roxide.service

# Start manually
systemctl --user start roxide.service

# View logs
journalctl --user -u roxide.service -f
```

---

## Troubleshooting

### Quickshell Qt module not found

Ensure `QT_QML_IMPORT_PATH` includes Qt6 QML paths:
```bash
echo $QT_QML_IMPORT_PATH  # Should include Qt6 paths
```

### Socket connection failed

Check that roxide daemon is running:
```bash
systemctl --user status roxide.service
```

### Missing dependencies

Install required Qt6 components:
- `qt6-base`
- `qt6-declarative` 
- `qt6-multimedia`
- `qt6-imageformats`
- `kirigami`
- `sonnet`

---

## License

RoxideDesktopShell Core is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.