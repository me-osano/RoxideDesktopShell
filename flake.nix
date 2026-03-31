{
  description = "RUSTIQ desktop shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };

        rustToolchain = pkgs.rust-bin.stable.latest.default;

        rustiqCore = pkgs.rustPlatform.buildRustPackage {
          pname = "rustiq";
          version = "0.1.0";
          src = ./core;
          cargoLock.lockFile = ./core/Cargo.lock;

          nativeBuildInputs = with pkgs; [ pkg-config ];
          buildInputs = with pkgs; [
            openssl
            dbus
          ];
        };
      in
      {
        packages.default = rustiqCore;

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rustToolchain
            pkg-config
            openssl
            dbus
            quickshell
            cargo-watch
          ];
        };
      }
    ) // {
      # Home Manager module
      homeModules.default = { config, lib, pkgs, ... }:
        let cfg = config.programs.rustiq;
        in {
          options.programs.rustiq = {
            enable = lib.mkEnableOption "RUSTIQ desktop shell";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.default;
            };

            logLevel = lib.mkOption {
              type = lib.types.str;
              default = "info";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ cfg.package ];

            # Shell config symlink
            xdg.configFile."rustiq/quickshell".source = ./quickshell;

            # Systemd user service
            systemd.user.services.rustiq = {
              Unit = {
                Description = "RUSTIQ desktop shell daemon";
                After = [ "graphical-session.target" ];
                PartOf = [ "graphical-session.target" ];
              };
              Service = {
                ExecStart = "${cfg.package}/bin/rustiq daemon";
                Restart = "on-failure";
                RestartSec = "3s";
                Environment = [ "RUSTIQ_LOG=${cfg.logLevel}" ];
              };
              Install.WantedBy = [ "graphical-session.target" ];
            };
          };
        };
    };
}
