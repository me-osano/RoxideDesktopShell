.PHONY: build install run dev clean

BUILD_DIR := core/target/release
BIN := $(BUILD_DIR)/rustiq
PREFIX ?= $(HOME)/.local

build:
	cd core && cargo build --release

install: build
	install -Dm755 $(BIN) $(PREFIX)/bin/rustiq
	mkdir -p $(HOME)/.config/rustiq
	cp -r quickshell $(HOME)/.config/rustiq/
	install -Dm644 distro/arch/rustiq.service $(HOME)/.config/systemd/user/
	systemctl --user daemon-reload
	@echo "Run: make enable"

enable:
	systemctl --user enable --now rustiq.service

disable:
	systemctl --user disable --now rustiq.service

run: build
	RUSTIQ_LOG=debug $(BIN) daemon &
	sleep 1
	quickshell -p quickshell/

dev:
	cd core && cargo watch -x 'build' &
	quickshell -p quickshell/

logs:
	journalctl --user -u rustiq -f

clean:
	cd core && cargo clean

status:
	$(PREFIX)/bin/rustiq status

fmt:
	cd core && cargo fmt

check:
	cd core && cargo check && cargo clippy
