# RUSTIQ Commands

> Command-line interface for RUSTIQ desktop shell daemon.

## Table of Contents

- [Usage](#usage)
- [Commands](#commands)
  - [daemon](#daemon)
  - [status](#status)
  - [sysmon](#sysmon)
  - [search](#search)
  - [weather](#weather)
  - [niri](#niri)
- [IPC Socket](#ipc-socket)

## Usage

```bash
rustiq [COMMAND]
```

---

## Commands

### daemon

> Start the RUSTIQ daemon in the background.

```bash
rustiq daemon
```

---

### status

> Check if the RUSTIQ daemon is running.

```bash
rustiq status
```

**Output:**

```
RUSTIQ daemon: running (/run/user/1000/rustiq.sock)
```

---

### sysmon

> Print system monitoring snapshot.

```bash
rustiq sysmon
```

**Output:**

```
Use: curl --unix-socket $XDG_RUNTIME_DIR/rustiq.sock http://localhost/sysmon | jq
```

---

### search

> Search files using the daemon's search functionality.

```bash
rustiq search <query> [--limit <number>]
```

| Argument | Description | Default |
|-----------|-------------|---------|
| `query` | Search query string (required) | — |
| `--limit, -l` | Maximum results | `10` |

**Example:**

```bash
rustiq search "rust" --limit 20
```

**Output:**

```
Use: curl --unix-socket $XDG_RUNTIME_DIR/rustiq.sock 'http://localhost/search?q=rust&limit=20' | jq
```

---

### weather

> Print current weather snapshot.

```bash
rustiq weather
```

**Output:**

```
Use: curl --unix-socket $XDG_RUNTIME_DIR/rustiq.sock http://localhost/weather | jq
```

---

### niri

> Niri window manager IPC commands.

```bash
rustiq niri <subcommand>
```

#### Subcommands

| Subcommand | Description |
|------------|-------------|
| `workspaces` | List all workspaces |
| `windows` | List all windows |
| `activate <id>` | Activate a workspace by ID |
| `focus <id>` | Focus a window by ID |

---

#### workspaces

> List all workspaces.

```bash
rustiq niri workspaces
```

**Output:**

```
Use: curl --unix-socket $XDG_RUNTIME_DIR/rustiq.sock http://localhost/niri/workspaces | jq
```

---

#### windows

> List all windows.

```bash
rustiq niri windows
```

**Output:**

```
Use: curl --unix-socket $XDG_RUNTIME_DIR/rustiq.sock http://localhost/niri/windows | jq
```

---

#### activate

> Activate a workspace by ID.

```bash
rustiq niri activate <id>
```

| Argument | Description |
|----------|-------------|
| `id` | Workspace ID (required) |

**Example:**

```bash
rustiq niri activate 1
```

**Output:**

```
Use: curl -X POST --unix-socket $XDG_RUNTIME_DIR/rustiq.sock http://localhost/niri/workspace/1/activate
```

---

#### focus

> Focus a window by ID.

```bash
rustiq niri focus <id>
```

| Argument | Description |
|----------|-------------|
| `id` | Window ID (required) |

**Example:**

```bash
rustiq niri focus 5
```

**Output:**

```
Use: curl -X POST --unix-socket $XDG_RUNTIME_DIR/rustiq.sock http://localhost/niri/window/5/focus
```

---

## IPC Socket

> The daemon exposes a Unix socket at `$XDG_RUNTIME_DIR/rustiq.sock` (typically `/run/user/1000/rustiq.sock`).

All commands can also be accessed directly via HTTP:

```bash
curl --unix-socket $XDG_RUNTIME_DIR/rustiq.sock http://localhost/<endpoint>
```