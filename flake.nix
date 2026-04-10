{
  description = "RUSTIQ desktop shell (RDS) - a Wayland desktop shell built with Quickshell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell?rev=41828c4180fb921df7992a5405f5ff05d2ac2fff";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      quickshell,
      ...
    }:
    let
      forEachSystem =
        fn:
        nixpkgs.lib.genAttrs nixpkgs.lib.platforms.linux (
          system: fn system nixpkgs.legacyPackages.${system}
        );

      buildRustiqPkgs = pkgs: {
        rustiq-shell = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        quickshell = quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };

      mkModuleWithRustiqPkgs =
        modulePath:
        args@{ pkgs, ... }:
        {
          imports = [
            (import modulePath (args // { rustiqPkgs = buildRustiqPkgs pkgs; }))
          ];
        };

      mkQmlImportPath =
        pkgs: qmlPkgs:
        pkgs.lib.concatStringsSep ":" (map (o: "${o}/${pkgs.qt6.qtbase.qtQmlPrefix}") qmlPkgs);

      mkQtPluginPath =
        pkgs: qtPkgs:
        pkgs.lib.concatStringsSep ":" (map (o: "${o}/${pkgs.qt6.qtbase.qtPluginPrefix}") qtPkgs);

      qmlPkgs =
        pkgs: with pkgs.kdePackages; [
          kirigami.unwrapped
          sonnet
          qtmultimedia
          qtimageformats
          kimageformats
        ];
    in
    {
      packages = forEachSystem (
        system: pkgs:
        let
          mkDate =
            longDate:
            pkgs.lib.concatStringsSep "-" [
              (builtins.substring 0 4 longDate)
              (builtins.substring 4 2 longDate)
              (builtins.substring 6 2 longDate)
            ];
          version =
            let
              rawVersion = pkgs.lib.removePrefix "v" (pkgs.lib.trim (builtins.readFile ./quickshell/VERSION));
              cleanVersion = builtins.replaceStrings [ " " ] [ "" ] rawVersion;
              dateSuffix = "+date=" + mkDate (self.lastModifiedDate or "19700101");
              revSuffix = "_" + (self.shortRev or "dirty");
            in
            "${cleanVersion}${dateSuffix}${revSuffix}";

          coreSrc = ./core;
          #cargoHash = "sha256-WZu3zmSW8io9iJG+AiIdTLftoUy1gD6jv08gM8Ops6U=";

          qtPackages = qmlPkgs pkgs;
        in
        {
          rustiq-shell = pkgs.lib.makeOverridable (
            {
              extraQtPackages ? [ ],
            }:
            (pkgs.rustPlatform.buildRustPackage.override { }) (
              let
                rustiqPkgs = pkgs;
              in
              {
                inherit version;
                pname = "rustiq-shell";
                src = coreSrc;
                cargoLock.lockFile = ./core/Cargo.lock;

                nativeBuildInputs = with rustiqPkgs; [
                  pkg-config
                  makeWrapper
                ];

                buildInputs = with rustiqPkgs; [
                  openssl
                  dbus
                ];

                postInstall = ''
                  mkdir -p $out/share/quickshell/rustiq-shell
                  cp -r ${./quickshell}/. $out/share/quickshell/rustiq-shell/

                  wrapProgram $out/bin/rustiq \
                    --add-flags "-c $out/share/quickshell/rustiq-shell" \
                    --prefix "NIXPKGS_QT6_QML_IMPORT_PATH" ":" "${
                      mkQmlImportPath rustiqPkgs (qtPackages ++ extraQtPackages)
                    }" \
                    --prefix "QT_PLUGIN_PATH" ":" "${mkQtPluginPath rustiqPkgs (qtPackages ++ extraQtPackages)}"
                '';

                meta = {
                  description = "Wayland desktop shell built with Quickshell";
                  homepage = "https://github.com/me-osano/rustiq-shell";
                  license = pkgs.lib.licenses.mit;
                  mainProgram = "rustiq";
                  platforms = pkgs.lib.platforms.linux;
                };
              }
            )
          ) { };

          quickshell = quickshell.packages.${system}.default;

          default = self.packages.${system}.rustiq-shell;
        }
      );

      homeModules.default = mkModuleWithRustiqPkgs ./distro/nixos/home-module.nix;

      devShells = forEachSystem (
        system: pkgs:
        let
          devQmlPkgs = [
            quickshell.packages.${system}.default
            pkgs.kdePackages.qtdeclarative
          ]
          ++ (qmlPkgs pkgs);
        in
        {
          default = pkgs.mkShell {
            buildInputs =
              with pkgs;
              [
                (pkgs.rust-bin.stable.latest.default)
                pkgs.rust-analyzer
                pkgs.cargo-audit
                pkgs.cargo-outdated

                pkgs.systemd
                pkg-config

                nixfmt-rfc-style
                statix
                deadnix

                lefthook
              ]
              ++ devQmlPkgs;

            shellHook = ''
              touch quickshell/.qmlls.ini 2>/dev/null
            '';

            NIXPKGS_QT6_QML_IMPORT_PATH = mkQmlImportPath pkgs devQmlPkgs;
            QT_PLUGIN_PATH = mkQtPluginPath pkgs devQmlPkgs;
          };
        }
      );
    };
}
