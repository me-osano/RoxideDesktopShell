# IPC - Inter-Process Communication

> RUSTIQ daemon IPC API documentation.

## Overview

The RUSTIQ daemon exposes a REST API over a Unix socket (`/run/user/1000/rustiq.sock`) and optionally a TCP port (default `127.0.0.1:8765`). All endpoints support JSON responses.

## Socket Path

```
$XDG_RUNTIME_DIR/rustiq.sock
```

Default: `/run/user/1000/rustiq.sock` (assuming UID 1000)

## TCP Port

```
127.0.0.1:8765
```

Override with `RUSTIQ_PORT` environment variable.

---

## Endpoints

### Health

| Method | Path | Description |
|--------|------|-------------|
| GET | `/ping` | Health check |

**Response:**

```json
{ "status": "ok", "version": "0.1.0" }
```

---

### System Monitor

| Method | Path | Description |
|--------|------|-------------|
| GET | `/sysmon` | System metrics snapshot |
| GET | `/sysmon/processes` | Detailed process list |

See [SYSMON.md](./SYSMON.md) for detailed response schemas.

---

### Weather

| Method | Path | Description |
|--------|------|-------------|
| GET | `/weather` | Current weather data |

---

### Search

| Method | Path | Description |
|--------|------|-------------|
| GET | `/search` | Full-text search |

**Query Parameters:**

| Parameter | Type | Description |
|------------|------|-------------|
| `q` | string | Search query (required) |
| `limit` | integer | Max results (default: 10) |

**Example:**

```bash
curl "http://localhost/search?q=rust&limit=20"
```

---

### Notifications

| Method | Path | Description |
|--------|------|-------------|
| GET | `/notifications` | Active notifications |
| GET | `/notifications/history` | Notification history |
| POST | `/notifications/:id/dismiss` | Dismiss notification |
| POST | `/notifications/dismiss-all` | Dismiss all |
| POST | `/notifications/clear-history` | Clear history |

---

### Clipboard

| Method | Path | Description |
|--------|------|-------------|
| GET | `/clipboard/list` | Clipboard history |
| POST | `/clipboard/:id/copy` | Copy item |
| POST | `/clipboard/:id/delete` | Delete item |
| POST | `/clipboard/wipe` | Clear history |
| GET | `/clipboard/:id/decode` | Decode item |

---

### Network

| Method | Path | Description |
|--------|------|-------------|
| GET | `/network` | Network status |
| POST | `/network/wifi` | WiFi control |

---

### Bluetooth

| Method | Path | Description |
|--------|------|-------------|
| GET | `/bluetooth` | Bluetooth status |
| POST | `/bluetooth/set` | Toggle Bluetooth |

---

### Brightness

| Method | Path | Description |
|--------|------|-------------|
| GET | `/brightness` | Current brightness |
| POST | `/brightness` | Set brightness |
| GET | `/brightness/devices` | Available devices |
| POST | `/brightness/select` | Select device |
| POST | `/brightness/increase` | Increase brightness |
| POST | `/brightness/decrease` | Decrease brightness |

---

### Media

| Method | Path | Description |
|--------|------|-------------|
| GET | `/media` | Media player status |
| POST | `/media/:player/play` | Play |
| POST | `/media/:player/pause` | Pause |
| POST | `/media/:player/play-pause` | Toggle |
| POST | `/media/:player/stop` | Stop |
| POST | `/media/:player/next` | Next track |
| POST | `/media/:player/previous` | Previous track |

---

### Niri (Window Manager)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/niri/workspaces` | Workspace list |
| GET | `/niri/windows` | Window list |
| POST | `/niri/workspaces/:id/activate` | Activate workspace |
| POST | `/niri/windows/:id/focus` | Focus window |

---

### Launch

| Method | Path | Description |
|--------|------|-------------|
| POST | `/launch` | Launch application |

---

## Server-Sent Events (SSE)

Subscribe to real-time events via `/events`.

**Query Parameters:**

| Parameter | Type | Description |
|------------|------|-------------|
| `filters` | string | Comma-separated event types |

**Event Types:**

- `sysmon_updated` - System metrics updated
- `weather_updated` - Weather data updated
- `niri_window_focus` - Window focused
- `niri_workspace_changed` - Workspace changed
- `niri_windows_changed` - Windows changed
- `notification` - New notification
- `notification_closed` - Notification closed
- `clipboard_updated` - Clipboard changed
- `brightness_updated` - Brightness changed
- `network_updated` - Network changed
- `bluetooth_updated` - Bluetooth changed
- `media_player_changed` - Media player state changed

**Example:**

```bash
curl -N "http://localhost/events?filters=sysmon_updated,notification"
```

**Event Format:**

```json
{ "type": "sysmon_updated", "data": { /* ... */ } }
```

---

## Usage Examples

### Using curl with Unix socket

```bash
# Health check
curl --unix-socket /run/user/1000/rustiq.sock http://localhost/ping

# Get sysmon
curl --unix-socket /run/user/1000/rustiq.sock http://localhost/sysmon

# Get sysmon JSON
curl --unix-socket /run/user/1000/rustiq.sock -H "Accept: application/json" http://localhost/sysmon
```

### Using curl with TCP

```bash
curl http://127.0.0.1:8765/ping
curl http://127.0.0.1:8765/sysmon
```

### Using the CLI

```bash
rustiq status
rustiq sysmon
rustiq sysmon --json
rustiq search "query"
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `XDG_RUNTIME_DIR` | `/tmp` | Socket directory |
| `RUSTIQ_PORT` | `8765` | TCP port |
| `RUSTIQ_LOG` | `info` | Log level |
