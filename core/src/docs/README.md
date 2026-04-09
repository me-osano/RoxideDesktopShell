# RUSTIQ CLI Documentation

Command-line interface for the RUSTIQ desktop shell daemon.

## Usage

```bash
rustiq [COMMAND]
```

## Process Management Commands

| Command | Description |
|---------|-------------|
| `rustiq daemon` | Start only the daemon (backend) |
| `rustiq run-rqs` | Run full shell (daemon + Quickshell UI) |
| `rustiq run-rqs -d` | Run in daemon mode (background) |
| `rustiq restart` | Kill and relaunch RUSTIQ |
| `rustiq kill` | Kill all RUSTIQ instances |

## Utility Commands

| Command | Description |
|---------|-------------|
| `rustiq status` | Check daemon status |
| `rustiq sysmon` | Print system monitoring snapshot |
| `rustiq search <query>` | Search files |
| `rustiq weather` | Print weather snapshot |
| `rustiq niri <subcommand>` | Niri workspace/window management |
| `rustiq brightness <subcommand>` | Brightness control |

## Examples

```bash
# Start daemon and shell
rustiq run-rqs

# Run in background
rustiq run-rqs -d

# Check status
rustiq status

# Get system stats
rustiq sysmon --json

# Restart after config changes
rustiq restart

# Stop RUSTIQ
rustiq kill
```

## Documentation

- [COMMANDS.md](./usage/COMMANDS.md) - Full command reference
- [IPC.md](./usage/IPC.md) - IPC API documentation
- [SYSMON.md](./usage/SYSMON.md) - System monitor documentation
