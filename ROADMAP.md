# RUSTIQ Roadmap

## v0.1 — Foundation ✦
- [x] Rust daemon skeleton (axum Unix socket)
- [x] Sysmon module (sysinfo crate)
- [x] Niri IPC module (workspace/window events)
- [x] Weather module (ip-api + open-meteo)
- [x] Search module (tantivy + notify)
- [x] Notifications D-Bus server (zbus)
- [x] QML bar (workspaces, title, clock, sysmon, weather)
- [x] QML launcher overlay
- [x] QML notification toasts
- [x] QML OSD (volume/brightness)
- [x] QML greeter skeleton
- [x] systemd user service
- [x] NixOS flake + Home Manager module

## v0.2 — Polish
- [ ] SSE event stream (replace polling in QML)
- [ ] System tray (StatusNotifierItem D-Bus)
- [ ] Bluetooth widget (bluez via zbus)
- [ ] Network manager integration (detailed wifi/eth status)
- [ ] Clipboard manager
- [ ] Wallpaper integration (swww or wpaperd)
- [ ] Matugen color extraction (or hardcoded Catppuccin variants)
- [ ] Greeter greetd auth IPC
- [ ] Per-app niri window rules via IPC
- [ ] GPU metrics (AMD sysfs /sys/class/drm/)

## v0.3 — Features
- [ ] Plugin system (WASM plugins? Lua scripts?)
- [ ] Calendar widget (CalDAV sync)
- [ ] Screenshot tool integration
- [ ] Idle/lock screen (swayidle replacement in Rust)
- [ ] Multi-monitor proper support
- [ ] Config file (~/.config/rustiq/config.toml)
- [ ] Dashboard overlay (DankDash equivalent)

## v1.0 — Daily Driver
- [ ] Full docs site
- [ ] AUR package
- [ ] NixOS flake stable
- [ ] Codeberg mirror
