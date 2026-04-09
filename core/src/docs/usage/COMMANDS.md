# RUSTIQ Commands

> Command-line interface for RUSTIQ desktop shell daemon.

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
rustiq [COMMAND]
```

---

## Commands

### daemon

> Start only the RUSTIQ daemon (backend).

```bash
rustiq daemon
```

---

### run-rds

> Run RUSTIQ (daemon + Quickshell UI). This is the main command to launch the full shell.

```bash
rustiq run-rds [--daemon] [--session]
```

| Argument | Description |
|----------|-------------|
| `--daemon, -d` | Run in daemon mode (detached from terminal) |
| `--session` | Session managed mode (for use with systemd) |

**Examples:**

```bash
# Run attached to terminal (for testing)
rustiq run-rds

# Run in daemon mode (background)
rustiq run-rds --daemon

# Run for systemd session management
rustiq run-rds --session
```

---

### restart

> Kill the RUSTIQ daemon and relaunch it. Useful after configuration changes.

```bash
rustiq restart
```

**Example:**

```bash
# Restart to apply configuration changes
rustiq restart
```

---

### kill

> Kill all running RUSTIQ instances.

```bash
rustiq kill
```

**Example:**

```bash
# Stop RUSTIQ
rustiq kill
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

> Print system monitoring snapshot with diagnostics.

```bash
rustiq sysmon [--verbose] [--json]
```

| Argument | Description |
|----------|-------------|
| `--verbose, -v` | Show detailed output including paths, versions, and per-core CPU |
| `--json, -j` | Output results in JSON format |

**Example:**

```bash
rustiq sysmon
rustiq sysmon --verbose
rustiq sysmon --json
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
    ● RUSTIQ CLI ...... OK (v0.1.0)
    ● IPC Socket ...... OK (Found at /run/user/1000/rustiq.sock)
    ● Active .......... OK (niri)

  Status:
    ✓ All systems operational
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

### brightness

> Control display brightness for backlights and monitors.

```bash
rustiq brightness <subcommand>
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
rustiq brightness list
rustiq brightness set backlight:amdgpu_bl1 50
rustiq brightness increase 5 --exponential
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