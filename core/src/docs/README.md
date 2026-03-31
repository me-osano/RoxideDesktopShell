# RustiqShell Core Documentation

Welcome to the **RustiqShell Core** documentation! This document provides an overview of the core components, their functionality, and how to contribute to the development of RustiqShell.

## Overview

RustiqShell Core is the backend daemon for the Rustiq desktop shell, designed specifically for the **Niri Wayland compositor**. It provides system integration, inter-process communication (IPC), and essential services for the shell's functionality.

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

To build the RustiqShell core, run the following commands:

```bash
# Navigate to the core directory
cd core

# Build the project
cargo build --release
```

The compiled binary will be located in `target/release/rustiqshell`.

---

## CLI Commands

The RustiqShell core provides a command-line interface for interacting with the shell. Below are some of the available commands:

- `rustiqshell status`: Check the health of the daemon.
- `rustiqshell sysmon`: Display system statistics.
- `rustiqshell search <query>`: Perform a full-text search.
- `rustiqshell weather`: Fetch current weather data.
- `rustiqshell niri workspaces`: List available workspaces.
- `rustiqshell niri windows`: List open windows.

---

## Wayland Protocols

RustiqShell Core integrates with Niri-specific Wayland protocols to provide advanced functionality. These include:
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

We welcome contributions to RustiqShell Core! To get started:
1. Fork the repository.
2. Create a new branch for your changes.
3. Test your changes thoroughly.
4. Open a pull request.

For more details, see the [CONTRIBUTING.md](../CONTRIBUTING.md) file.

---

## License

RustiqShell Core is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.

---