# ROXIDE Commands

> Command-line interface for ROXIDE desktop shell daemon.

## Table of Contents

- [Usage](#usage)
- [Commands](#commands)
  - [daemon](#daemon)
  - [run-rds](#run-rds)
  - [restart](#restart)
  - [kill](#kill)
  - [status](#status)
  - [sysmon](#sysmon)
  - [search](#search)
  - [weather](#weather)
  - [brightness](#brightness)
  - [niri](#niri)
- [IPC Socket](#ipc-socket)

## Usage

```bash
roxide [COMMAND]
```

---

## Commands

### daemon

> Start only the ROXIDE daemon (backend).

```bash
roxide daemon
```

---

### run-rds

> Run ROXIDE (daemon + Quickshell UI). This is the main command to launch the full shell.

```bash
roxide run-rds [--daemon] [--session]
```

| Argument | Description |
|----------|-------------|
| `--daemon, -d` | Run in daemon mode (detached from terminal) |
| `--session` | Session managed mode (for use with systemd) |

**Examples:**

```bash
# Run attached to terminal (for testing)
roxide run-rds

# Run in daemon mode (background)
roxide run-rds --daemon

# Run for systemd session management
roxide run-rds --session
```

---

### restart

> Kill the ROXIDE daemon and relaunch it. Useful after configuration changes.

```bash
roxide restart
```

**Example:**

```bash
# Restart to apply configuration changes
roxide restart
```

---

### kill

> Kill all running ROXIDE instances.

```bash
roxide kill
```

**Example:**

```bash
# Stop ROXIDE
roxide kill
```

---

### status

> Check if the ROXIDE daemon is running.

```bash
roxide status
```

**Output:**

```
ROXIDE daemon: running (/run/user/1000/roxide.sock)
```

---

### sysmon

> Print system monitoring snapshot with diagnostics.

```bash
roxide sysmon [--verbose] [--json]
```

| Argument | Description |
|----------|-------------|
| `--verbose, -v` | Show detailed output including paths, versions, and per-core CPU |
| `--json, -j` | Output results in JSON format |

**Example:**

```bash
roxide sysmon
roxide sysmon --verbose
roxide sysmon --json
```

**Output:**

```
  System Monitor

  CPU
    Usage: 12.5%
    Cores: 8
    Load: 0.15 / 0.20 / 0.25

  Memory
    Used: 65.2% (8192 / 16384 MB)
    Available: 6144 MB

  Disk
    / (ext4) 45.2% used (120 / 256 GB)

  Network
    wlp0s20f3: ↓1.2GB ↓rate:150.0KB/s  ↑450.0MB ↑rate:50.0KB/s

  Processes (top 5 CPU)
    1: chrome 8.5% CPU 512 MB

  Uptime: 3600 secs

  Diagnostics
    ● Architecture .... OK (x86_64)
    ● Display Server .. OK (Wayland)
    ● ROXIDE CLI ...... OK (v0.1.0)
    ● IPC Socket ...... OK (Found at /run/user/1000/roxide.sock)
    ● Active .......... OK (niri)

  Status:
    ✓ All systems operational
```

---

### search

> Search files using the daemon's search functionality.

```bash
roxide search <query> [--limit <number>]
```

| Argument | Description | Default |
|-----------|-------------|---------|
| `query` | Search query string (required) | — |
| `--limit, -l` | Maximum results | `10` |

**Example:**

```bash
roxide search "rust" --limit 20
```

**Output:**

```
Use: curl --unix-socket $XDG_RUNTIME_DIR/roxide.sock 'http://localhost/search?q=rust&limit=20' | jq
```

---

### weather

> Print current weather snapshot.

```bash
roxide weather
```

**Output:**

```
Use: curl --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/weather | jq
```

---

### brightness

> Control display brightness for backlights and monitors.

```bash
roxide brightness <subcommand>
```

#### Subcommands

| Subcommand | Description |
|------------|-------------|
| `list [--ddc]` | List all available brightness devices |
| `get <device> [--ddc]` | Get current brightness for a device |
| `set <device> <percent> [--ddc] [--exponential] [--exponent <value>]` | Set brightness percentage |
| `increase <delta> [--exponential] [--exponent <value>]` | Increase brightness |
| `decrease <delta> [--exponential] [--exponent <value>]` | Decrease brightness |

| Argument | Description |
|----------|-------------|
| `--ddc` | Include DDC/I2C monitors (slower) |
| `--exponential` | Use exponential brightness scaling |
| `--exponent` | Exponent for exponential scaling (default: 1.2) |

**Example:**

```bash
roxide brightness list
roxide brightness set backlight:amdgpu_bl1 50
roxide brightness increase 5 --exponential
```

---

### niri

> Niri window manager IPC commands.

```bash
roxide niri <subcommand>
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
roxide niri workspaces
```

**Output:**

```
Use: curl --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/niri/workspaces | jq
```

---

#### windows

> List all windows.

```bash
roxide niri windows
```

**Output:**

```
Use: curl --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/niri/windows | jq
```

---

#### activate

> Activate a workspace by ID.

```bash
roxide niri activate <id>
```

| Argument | Description |
|----------|-------------|
| `id` | Workspace ID (required) |

**Example:**

```bash
roxide niri activate 1
```

**Output:**

```
Use: curl -X POST --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/niri/workspace/1/activate
```

---

#### focus

> Focus a window by ID.

```bash
roxide niri focus <id>
```

| Argument | Description |
|----------|-------------|
| `id` | Window ID (required) |

**Example:**

```bash
roxide niri focus 5
```

**Output:**

```
Use: curl -X POST --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/niri/window/5/focus
```

---

## IPC Socket

> The daemon exposes a Unix socket at `$XDG_RUNTIME_DIR/roxide.sock` (typically `/run/user/1000/roxide.sock`).

All commands can also be accessed directly via HTTP:

```bash
curl --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/<endpoint>
```