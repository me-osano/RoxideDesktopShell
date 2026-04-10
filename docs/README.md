<file_path>
Projects/RoxideDesktopShell/docs/README.md
</file_path>

# RoxideDesktopShell Core Documentation

Welcome to the **RoxideDesktopShell Core** documentation! This document provides an overview of the core components, their functionality, and how to contribute to the development of RoxideDesktopShell.

## Overview

Roxide Core is the backend daemon for the Roxide desktop shell, designed specifically for the **Niri Wayland compositor**. It provides system integration, inter-process communication (IPC), and essential services for the shell's functionality.

### Key Features
- **Wayland Protocols**: Integration with Niri-specific Wayland protocols for workspace and window management.
- **DBus Integration**: Communication with system services like NetworkManager, BlueZ, and systemd.
- **CLI Commands**: A command-line interface for managing the shell and interacting with the core.
- **System Monitoring**: Real-time CPU, RAM, and network statistics.
- **Search**: Full-text search powered by Tantivy.
- **Weather**: Fetch current weather data using an HTTP client.

---

## Directory Structure

The core is organized as follows:

```
core/
├── src/
│   ├── cli/         # Command-line interface
│   ├── dbus/        # DBus integration
│   ├── wayland/     # Wayland protocol support
│   ├── ipc/         # Inter-process communication
│   ├── sysmon/      # System monitoring
│   ├── search/      # Full-text search
│   ├── weather/     # Weather data integration
│   └── main.rs      # Entry point for the core daemon
├── Cargo.toml       # Rust dependencies and metadata
└── Cargo.lock       # Dependency lock file
```

---

## Getting Started

### Prerequisites
- **Rust**: Version 1.75 or higher.
- **Niri**: Wayland compositor.
- **System Dependencies**:
  - `pipewire` / `wireplumber` for audio.
  - `networkmanager` for network management.
  - `greetd` for the greeter.

### Building the Core

To build the Roxide core, run the following commands:

```bash
# Navigate to the core directory
cd core

# Build the project
cargo build --release
```

The compiled binary will be located in `target/release/RoxideDesktopShell`.

---

## CLI Commands

The Roxide core provides a command-line interface for interacting with the shell. Below are some of the available commands:

- `roxide status`: Check the health of the daemon.
- `roxide sysmon`: Display system statistics.
- `roxide search <query>`: Perform a full-text search.
- `roxide weather`: Fetch current weather data.
- `roxide niri workspaces`: List available workspaces.
- `roxide niri windows`: List open windows.

---

## Wayland Protocols

RoxideDesktopShell Core integrates with Niri-specific Wayland protocols to provide advanced functionality. These include:
- Workspace and window management.
- Clipboard history and persistence.
- Display configuration.

---

## DBus Integration

The core communicates with system services using DBus. Supported interfaces include:
- `org.freedesktop.NetworkManager`: Network management.
- `org.bluez`: Bluetooth management.
- `org.freedesktop.login1`: Session control and brightness management.

---

## Contributing

We welcome contributions to Roxide Core! To get started:
1. Fork the repository.
2. Create a new branch for your changes.
3. Test your changes thoroughly.
4. Open a pull request.

For more details, see the [CONTRIBUTING.md](../CONTRIBUTING.md) file.

---

## License

RoxideDesktopShell Core is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.

---