# ROXIDE CLI Documentation

Command-line interface for the ROXIDE desktop shell daemon.

## Usage

```bash
roxide [COMMAND]
```

## Process Management Commands

| Command | Description |
|---------|-------------|
| `roxide daemon` | Start only the daemon (backend) |
| `roxide run-rds` | Run full shell (daemon + Quickshell UI) |
| `roxide run-rds -d` | Run in daemon mode (background) |
| `roxide restart` | Kill and relaunch ROXIDE |
| `roxide kill` | Kill all ROXIDE instances |

## Utility Commands

| Command | Description |
|---------|-------------|
| `roxide status` | Check daemon status |
| `roxide sysmon` | Print system monitoring snapshot |
| `roxide search <query>` | Search files |
| `roxide weather` | Print weather snapshot |
| `roxide niri <subcommand>` | Niri workspace/window management |
| `roxide brightness <subcommand>` | Brightness control |

## Examples

```bash
# Start daemon and shell
roxide run-rds

# Run in background
roxide run-rds -d

# Check status
roxide status

# Get system stats
roxide sysmon --json

# Restart after config changes
roxide restart

# Stop ROXIDE
roxide kill
```

## Documentation

- [COMMANDS.md](./usage/COMMANDS.md) - Full command reference
- [IPC.md](./usage/IPC.md) - IPC API documentation
- [SYSMON.md](./usage/SYSMON.md) - System monitor documentation
