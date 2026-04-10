.PHONY: build install run dev clean

BUILD_DIR := core/target/release
BIN := $(BUILD_DIR)/roxide
PREFIX ?= $(HOME)/.local

build:
	cd core && cargo build --release

install: build
	install -Dm755 $(BIN) $(PREFIX)/bin/roxide
	mkdir -p $(HOME)/.config/roxide
	cp -r quickshell $(HOME)/.config/roxide/
	install -Dm644 distro/arch/roxide.service $(HOME)/.config/systemd/user/
	systemctl --user daemon-reload
	@echo "Run: make enable"

enable:
	systemctl --user enable --now roxide.service

disable:
	systemctl --user disable --now roxide.service

run: build
	ROXIDE_LOG=debug $(BIN) daemon &
	sleep 1
	quickshell -p quickshell/

dev:
	cd core && cargo watch -x 'build' &
	quickshell -p quickshell/

logs:
	journalctl --user -u roxide -f

clean:
	cd core && cargo clean

status:
	$(PREFIX)/bin/roxide status

fmt:
	cd core && cargo fmt

check:
	cd core && cargo check && cargo clippy
