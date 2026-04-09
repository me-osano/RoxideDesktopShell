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

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      rust-overlay,
    }:
    let
      coreSrc = ./core;
      cargoHash = "sha256-6f30c75cf061b51ba17b3cb8dc9486346ff2f8fb40ae2b4d2856e70c387c81f0";
      overlay = final: prev: {
        rustiq-shell = final.pkgsStatic.rustPlatform.buildRustPackage {
          pname = "rustiq-shell";
          version = "0.1.0";
          src = coreSrc;
          inherit cargoHash;

          nativeBuildInputs = with final.pkgs; [ pkg-config ];
          buildInputs = with final.pkgs; [
            openssl
            dbus
          ];
        };
      };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            rust-overlay.overlays.default
            overlay
          ];
        };
      in
      {
        packages.default = pkgs.rustiq-shell;
        packages.x86_64-linux = pkgs.rustiq-shell;

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            (pkgs.rust-bin.stable.latest.default.override {
              targets = [ pkgs.rust-bin.stable.latest.default.RustTarget.x86_64-unknown-linux-gnu ];
            })
            pkg-config
            openssl
            dbus
            quickshell
            cargo-watch
          ];
        };
      }
    )
    // {
      # Home Manager module
      homeModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.rustiq-shell;
        in
        {
          options.programs.rustiq-shell = {
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

            xdg.configFile."rustiq-shell/quickshell".source = ./quickshell;

            systemd.user.services.rustiq-shell = {
              Unit = {
                Description = "RUSTIQ desktop shell daemon";
                After = [ "graphical-session.target" ];
                PartOf = [ "graphical-session.target" ];
              };
              Service = {
                ExecStart = "${cfg.package}/bin/rustiq-shell daemon";
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
