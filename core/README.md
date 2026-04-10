# Roxide Core

Backend daemon for the Roxide desktop shell, designed for the **Niri Wayland compositor**.

## Features

| Module | Description | Status |
|--------|-------------|--------|
| `sysmon` | CPU, RAM, network, disk monitoring | ✅ Production |
| `niri` | Workspace/window management via IPC socket | ✅ Production |
| `weather` | Weather data with geolocation caching | ✅ Production |
| `search` | Full-text file search (Tantivy) | ✅ Production |
| `notify` | D-Bus notifications with history | ✅ Production |
| `geolocation` | IP-based location with 1hr TTL cache | ✅ Production |
| `network` | NetworkManager state | ⚙️ Stub |
| `bluetooth` | BlueZ state | ⚙️ Stub |
| `clipboard` | Clipboard history (cliphist) | ⚙️ Stub |
| `brightness` | Display brightness (ddcutil) | ⚙️ Stub |
| `media` | MPRIS media player control | ⚙️ Stub |

## Architecture

```
┌─────────────────────────────────────────────┐
│              RUST CORE (Daemon)             │
├──────────┬──────────┬──────────┬────────────┤
│ sysmon   │ niri    │ weather  │ search     │
│ network  │ bluet.  │ clip.    │ bright.    │
│ media    │ notify  │ geo      │            │
└──────────┴──────────┴──────────┴────────────┘
                      │ HTTP/SSE
┌─────────────────────────────────────────────┐
│              QML SHELL (UI)                 │
└─────────────────────────────────────────────┘
```

## Building

```bash
cd core
cargo build --release
```

## Running

```bash
# Process management (like DMS)
roxide daemon          # Start only the daemon
roxide run-rds         # Run full shell (daemon + Quickshell UI)
roxide run-rds -d      # Run in daemon mode (background)
roxide restart        # Restart ROXIDE
roxide kill           # Stop ROXIDE

# CLI utilities
roxide status
roxide sysmon
roxide search "query"
roxide weather
roxide niri workspaces
```

## IPC API

The daemon exposes an HTTP API (default port 8765):

### Endpoints

```
GET  /ping                          # Health check
GET  /sysmon                        # System statistics
GET  /weather                       # Current weather
GET  /search?q=<query>&limit=<n>    # File search
GET  /niri/workspaces               # Workspace list
GET  /niri/windows                  # Window list
POST /niri/workspaces/<id>/activate # Switch workspace
POST /niri/windows/<id>/focus       # Focus window
GET  /notifications                 # Active notifications
GET  /notifications/history         # Notification history
POST /notifications/<id>/dismiss    # Dismiss notification
POST /notifications/dismiss-all      # Dismiss all
GET  /network                       # Network state
POST /network/wifi                  # Toggle wifi
GET  /bluetooth                     # Bluetooth state
GET  /clipboard                     # Clipboard items
POST /clipboard/<id>/copy           # Copy item
POST /clipboard/<id>/delete         # Delete item
GET  /brightness                    # Brightness state
POST /brightness                    # Set brightness (0-1)
POST /brightness/increase           # Increase by delta
POST /brightness/decrease           # Decrease by delta
GET  /media                         # Media player state
POST /media/<player>/play           # Play
POST /media/<player>/pause          # Pause
POST /media/<player>/toggle         # Play/Pause
```

### Server-Sent Events

Subscribe to real-time updates:

```bash
curl http://localhost:8765/events
```

Event types:
- `sysmon_updated` - System stats changed
- `weather_updated` - Weather data refreshed
- `niri_window_focus` - Window focused
- `niri_workspace_changed` - Workspace switched
- `notification` - New notification
- `notification_closed` - Notification dismissed
- `clipboard_updated` - Clipboard changed
- `brightness_updated` - Brightness changed
- `network_updated` - Network state changed
- `bluetooth_updated` - Bluetooth state changed
- `media_player_changed` - Media player state

## Dependencies

### Required
- Rust 1.75+
- Niri (Wayland compositor)

### Optional (for full functionality)
- `cliphist` - Clipboard history
- `ddcutil` - Display brightness control
- NetworkManager - Network management
- BlueZ - Bluetooth

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ROXIDE_PORT` | `8765` | HTTP server port |
| `ROXIDE_LOG` | `info` | Log level (trace, debug, info, warn, error) |
| `NIRI_SOCKET` | - | Niri IPC socket path |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run `cargo build` to verify compilation
4. Submit a pull request

## License

Roxide Core is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.
