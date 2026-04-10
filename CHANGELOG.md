# Changelog

All notable changes to ROXIDE desktop shell will be documented in this file.

## [Unreleased]

### Added
- Nix flake with devShell, packages, and home-manager module
- Quickshell-based QML frontend
- Rust backend daemon (`roxide`) with IPC over Unix socket
- Workspace bar with Niri integration
- Application launcher with file search (tantivy)
- System monitoring (CPU, RAM, network, battery)
- Weather widget with geolocation
- Media controls via MPRIS
- Notifications server (D-Bus)
- Clipboard manager
- Brightness control
- VPN and network management
- Night light / color temperature
- Lock keys indicator
- Calendar integration
- Emoji picker
- Template system for widgets

### Build
- Cargo-based Rust build
- QML module imports via qt6 kdePackages
- Nix packaging with overlays

## [0.1.0] - 2024-01-01

### Added
- Initial release
- Basic bar and launcher
- System daemon

[Unreleased]: https://github.com/me-osano/RoxideDesktopShell/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/me-osano/RoxideDesktopShell/releases/tag/v0.1.0