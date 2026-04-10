# sysd

A minimal Rust system control daemon + CLI for Wayland/Linux.
Handles **brightness**, **Bluetooth**, **network**, **clipboard**, and **notifications**
over a Unix socket IPC with a JSON protocol.

## Architecture

```
sysd/
├── crates/
│   ├── sysd-proto/      # Shared IPC types (Request / Response enums)
│   ├── sysd-daemon/     # `sysdd` — tokio daemon, Unix socket server
│   └── sysd-cli/        # `sysd`  — thin client CLI (clap subcommands)
└── contrib/
    ├── systemd/sysd.service      # systemd user service
    └── udev/90-sysd-backlight.rules
```

**IPC transport:** `$XDG_RUNTIME_DIR/sysd.sock` (Unix domain socket)  
**Protocol:** newline-delimited JSON (`Request` → `Response`)

## Dependencies

| Module      | Backend                              |
|-------------|--------------------------------------|
| Brightness  | `/sys/class/backlight` (sysfs)       |
| Bluetooth   | BlueZ via `zbus` (D-Bus)             |
| Network     | NetworkManager via `zbus` (D-Bus)    |
| Clipboard   | `wl-copy` / `wl-paste` subprocess    |
| Notifications | `org.freedesktop.Notifications`    |

**Runtime deps:** `wl-clipboard`, `bluez`, `networkmanager`

## Setup

### 1. Build

```bash
cargo build --release
# Binaries: target/release/sysdd  target/release/sysd
```

### 2. Backlight permissions (one-time)

```bash
sudo cp contrib/udev/90-sysd-backlight.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger
sudo usermod -aG video $USER   # re-login after this
```

### 3. Systemd user service

```bash
mkdir -p ~/.config/systemd/user
cp contrib/systemd/sysd.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now sysd
```

## CLI Usage

```bash
# Brightness
sysd brightness get
sysd brightness set 75
sysd brightness inc 10
sysd brightness dec 5

# Bluetooth (alias: bt)
sysd bt status
sysd bt toggle
sysd bt on / off
sysd bt scan
sysd bt list
sysd bt connect AA:BB:CC:DD:EE:FF
sysd bt disconnect AA:BB:CC:DD:EE:FF

# Network (alias: net)
sysd net status
sysd net list
sysd net toggle
sysd net disconnect

# Clipboard (alias: clip)
sysd clip get
sysd clip set "hello world"
sysd clip clear

# Notifications (alias: notif)
sysd notify send "Title" --body "Body text" --urgency critical
sysd notify send "Update done" --icon dialog-information --timeout 5000
sysd notify close 42

# Raw JSON output (QML/scripting friendly)
sysd --json brightness get
sysd --json bt status
```

## QML / Quickshell Integration

The daemon speaks newline-delimited JSON on `$XDG_RUNTIME_DIR/sysd.sock`,
making it trivial to integrate into RUSTIQ's Quickshell layer:

```qml
// Example: read brightness from sysd socket
IpcSocket {
    socketPath: StandardPaths.writableLocation(StandardPaths.RuntimeLocation) + "/sysd.sock"
    onConnected: sendMessage(JSON.stringify({ cmd: "brightness", action: "get" }) + "\n")
    onMessageReceived: {
        const r = JSON.parse(message)
        if (r.status === "ok") brightnessValue = r.percent
    }
}
```
