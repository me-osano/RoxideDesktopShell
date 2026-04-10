# Root Makefile for RoxideDesktopShell (RDS)
# Orchestrates building, installation, and systemd management

BINARY_NAME = roxide
CORE_DIR = core
BUILD_DIR = $(CORE_DIR)/target/release
PREFIX ?= usr/local
INSTALL_DIR = $(PREFIX)/bin
DATA_DIR = $(PREFIX)/share
ICON_DIR = $(DATA_DIR)/icons/hicolor/scalable/apps

USER_HOME := $(if $(SUDO_USER),$(shell getent passwd $(SUDO_USER) | cut -d: -f6),$(HOME))
SYSTEMD_USER_DIR = $(USER_HOME)/.config/systemd/user

SHELL_DIR = quickshell
SHELL_INSTALL_DIR = $(DATA_DIR)/quickshell/roxide
ASSETS_DIR = assets
APPLICATIONS_DIR = $(DATA_DIR)/applications

.PHONY: all build clean lint-qml fmt check \
	install install-bin install-shell install-completions install-systemd install-icon install-desktop \
	uninstall uninstall-bin uninstall-shell uninstall-completions uninstall-systemd uninstall-icon uninstall-desktop \
	enable disable logs status run dev help

all: build

build:
	@echo "Building $(BINARY_NAME)..."
	@cd core && cargo build --release
	@echo "Build complete"

clean:
	@echo "Cleaning build artifacts..."
	@cd core && cargo clean
	@echo "Clean complete"

fmt:
	@cd core && cargo fmt

check:
	@cd core && cargo check && cargo clippy

lint-qml:
	@./quickshell/scripts/qmllint-entrypoints.sh 2>/dev/null || echo "qmllint not available, skipping"

install-bin:
	@echo "Installing $(BINARY_NAME) to $(INSTALL_DIR)..."
	@mkdir -p $(INSTALL_DIR)
	@install -D -m 755 $(BUILD_DIR)/$(BINARY_NAME) $(INSTALL_DIR)/$(BINARY_NAME)
	@echo "Binary installed"

install-shell:
	@echo "Installing shell files to $(SHELL_INSTALL_DIR)..."
	@mkdir -p $(SHELL_INSTALL_DIR)
	@cp -r $(SHELL_DIR)/* $(SHELL_INSTALL_DIR)/
	@rm -rf $(SHELL_INSTALL_DIR)/.git* $(SHELL_INSTALL_DIR)/.github
	@echo "Shell files installed"

install-completions:
	@echo "Installing shell completions..."
	@mkdir -p $(DATA_DIR)/bash-completion/completions
	@mkdir -p $(DATA_DIR)/zsh/site-functions
	@$(BUILD_DIR)/$(BINARY_NAME) completion bash > $(DATA_DIR)/bash-completion/completions/roxide 2>/dev/null || true
	@$(BUILD_DIR)/$(BINARY_NAME) completion zsh > $(DATA_DIR)/zsh/site-functions/_roxide 2>/dev/null || true
	@echo "Shell completions installed"

install-systemd:
	@echo "Installing systemd user service..."
	@mkdir -p $(SYSTEMD_USER_DIR)
	@if [ -n "$(SUDO_USER)" ]; then chown -R $(SUDO_USER):"$(id -gn $SUDO_USER)" $(SYSTEMD_USER_DIR); fi
	@sed 's|/usr/bin/roxide|$(INSTALL_DIR)/roxide|g' $(ASSETS_DIR)/systemd/roxide.service > $(SYSTEMD_USER_DIR)/roxide.service
	@chmod 644 $(SYSTEMD_USER_DIR)/roxide.service
	@if [ -n "$(SUDO_USER)" ]; then chown $(SUDO_USER):"$(id -gn $SUDO_USER)" $(SYSTEMD_USER_DIR)/roxide.service; fi
	@systemctl --user daemon-reload 2>/dev/null || true
	@echo "Systemd service installed to $(SYSTEMD_USER_DIR)/roxide.service"

install-icon:
	@echo "Installing icon..."
	@mkdir -p $(ICON_DIR)
	@install -D -m 644 $(ASSETS_DIR)/roxidelogo.svg $(ICON_DIR)/roxidelogo.svg
	@gtk-update-icon-cache -q $(DATA_DIR)/icons/hicolor 2>/dev/null || true
	@echo "Icon installed"

install-desktop:
	@echo "Installing desktop entry..."
	@mkdir -p $(APPLICATIONS_DIR)
	@install -D -m 644 $(ASSETS_DIR)/roxide-open.desktop $(APPLICATIONS_DIR)/roxide-open.desktop
	@update-desktop-database -q $(APPLICATIONS_DIR) 2>/dev/null || true
	@echo "Desktop entry installed"

install: build install-bin install-shell install-completions install-systemd install-icon install-desktop
	@echo ""
	@echo "Installation complete!"
	@echo ""
	@echo "Run 'systemctl --user enable --now roxide' to start the service"

enable:
	@systemctl --user enable --now roxide.service

disable:
	@systemctl --user disable --now roxide.service

uninstall-bin:
	@echo "Removing $(BINARY_NAME) from $(INSTALL_DIR)..."
	@rm -f $(INSTALL_DIR)/$(BINARY_NAME)
	@echo "Binary removed"

uninstall-shell:
	@echo "Removing shell files from $(SHELL_INSTALL_DIR)..."
	@rm -rf $(SHELL_INSTALL_DIR)
	@echo "Shell files removed"

uninstall-completions:
	@echo "Removing shell completions..."
	@rm -f $(DATA_DIR)/bash-completion/completions/roxide
	@rm -f $(DATA_DIR)/zsh/site-functions/_roxide
	@rm -f $(DATA_DIR)/fish/vendor_completions.d/roxide.fish
	@echo "Shell completions removed"

uninstall-systemd:
	@echo "Removing systemd user service..."
	@systemctl --user disable --now roxide.service 2>/dev/null || true
	@rm -f $(SYSTEMD_USER_DIR)/roxide.service
	@systemctl --user daemon-reload 2>/dev/null || true
	@echo "Systemd service removed"

uninstall-icon:
	@echo "Removing icon..."
	@rm -f $(ICON_DIR)/roxidelogo.svg
	@gtk-update-icon-cache -q $(DATA_DIR)/icons/hicolor 2>/dev/null || true
	@echo "Icon removed"

uninstall-desktop:
	@echo "Removing desktop entry..."
	@rm -f $(APPLICATIONS_DIR)/roxide-open.desktop
	@update-desktop-database -q $(APPLICATIONS_DIR) 2>/dev/null || true
	@echo "Desktop entry removed"

uninstall: uninstall-systemd uninstall-desktop uninstall-icon uninstall-completions uninstall-shell uninstall-bin
	@echo ""
	@echo "Uninstallation complete!"

run: build
	ROXIDE_LOG=debug $(BUILD_DIR)/$(BINARY_NAME) run
	@echo "Session ended"

dev:
	cd core && cargo watch -x 'build' &
	quickshell -p $(SHELL_DIR)/

logs:
	journalctl --user -u roxide -f

status:
	$(INSTALL_DIR)/$(BINARY_NAME) status 2>/dev/null || echo "RDS daemon status unknown"

help:
	@echo "Available targets:"
	@echo ""
	@echo "Build:"
	@echo "  all (default)        - Build the RDS binary"
	@echo "  build                - Same as 'all'"
	@echo "  clean                - Clean build artifacts"
	@echo "  fmt                  - Format Rust code"
	@echo "  check                - Run cargo check and clippy"
	@echo "  lint-qml             - Run qmllint on shell entrypoints"
	@echo ""
	@echo "Run:"
	@echo "  run                  - Build and run in debug mode"
	@echo "  dev                  - Watch for changes and run in dev mode"
	@echo "  logs                 - Follow RDS daemon logs"
	@echo "  status               - Check daemon status"
	@echo ""
	@echo "Install:"
	@echo "  install              - Build and install everything (PREFIX=$(PREFIX))"
	@echo "  install-bin          - Install only the binary"
	@echo "  install-shell        - Install only shell files"
	@echo "  install-completions  - Install only shell completions"
	@echo "  install-systemd      - Install only systemd service"
	@echo "  install-icon         - Install only icon"
	@echo "  install-desktop      - Install only desktop entry"
	@echo ""
	@echo "Uninstall:"
	@echo "  uninstall            - Remove everything"
	@echo "  uninstall-bin        - Remove only the binary"
	@echo "  uninstall-shell      - Remove only shell files"
	@echo "  uninstall-completions - Remove only shell completions"
	@echo "  uninstall-systemd    - Remove only systemd service"
	@echo "  uninstall-icon       - Remove only icon"
	@echo "  uninstall-desktop    - Remove only desktop entry"
	@echo ""
	@echo "Service:"
	@echo "  enable               - Enable and start systemd service"
	@echo "  disable              - Disable and stop systemd service"
	@echo ""
	@echo "Usage:"
	@echo " sudo make install                        - Build and install roxide system-wide"
	@echo " sudo make uninstall                      - Remove system-wide install"
	@echo " systemctl --user enable --now roxide     - Enable and start service"
	#@echo "  make install PREFIX=~/.local    - Install to ~/.local (default)"
	#@echo "  make install PREFIX=/usr/local  - System-wide install (requires sudo)"
	#@echo "  make uninstall PREFIX=/usr/local - Remove system-wide install"
