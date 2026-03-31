# RUSTIQSHELL

> A handcrafted Wayland desktop shell for [niri](https://github.com/YaLTeR/niri), built with Quickshell/QML and a Rust backend.

```
  ██████╗ ██╗   ██╗███████╗████████╗██╗ ██████╗
  ██╔══██╗██║   ██║██╔════╝╚══██╔══╝██║██╔═══██╗
  ██████╔╝██║   ██║███████╗   ██║   ██║██║   ██║
  ██╔══██╗██║   ██║╚════██║   ██║   ██║██║▄▄ ██║
  ██║  ██║╚██████╔╝███████║   ██║   ██║╚██████╔╝
  ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝ ╚══▀▀═╝
```

## Architecture

```
rustiqshell/
├── core/         # Rust daemon — IPC, sysmon, search, weather, niri IPC
└── quickshell/   # QML shell — bar, launcher, widgets, notifications
```

The Rust core runs as a single systemd user daemon (`rustiq.service`).
Quickshell connects to it over a Unix socket at `$XDG_RUNTIME_DIR/rustiq.sock`.

## Features

- **Bar** — workspace switcher, window title, tray, clock, system stats
- **Launcher** — app search, file search (tantivy-indexed), calculator
- **Widgets** — CPU/RAM/network, weather, media controls, clipboard
- **Notifications** — D-Bus org.freedesktop.Notifications server
- **OSD** — volume/brightness overlays
- **Greeter** — greetd greeter (pure QML)
- **Theme** — Catppuccin Mocha throughout

## Dependencies

### Runtime
- `niri` — Wayland compositor
- `quickshell` — QML shell framework
- `pipewire` / `wireplumber` — audio
- `networkmanager` — network management
- `greetd` — display manager (for greeter)

### Build
- `rust` 1.75+
- `cargo`
- `qt6` / `qt6-declarative`

## Building

```bash
# Build Rust core
cd core && cargo build --release

# Install daemon + CLI
sudo install -Dm755 target/release/rustiq /usr/local/bin/rustiq

# Install systemd unit
install -Dm644 distro/arch/rustiq.service ~/.config/systemd/user/

# Launch shell
systemctl --user enable --now rustiq.service
quickshell -p ~/.config/rustiq/quickshell
```

## IPC

```bash
rustiq status           # daemon health
rustiq sysmon           # system snapshot
rustiq search "query"   # file search
rustiq weather          # current weather
rustiq niri workspaces  # workspace list
rustiq niri windows     # window list
```

## NixOS

```nix
{
  inputs.rustiq.url = "github:yourname/rustiq";
  imports = [ inputs.rustiq.homeModules.default ];
  programs.rustiq.enable = true;
}
```

## License


