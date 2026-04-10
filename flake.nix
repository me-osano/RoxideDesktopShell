{
  description = "ROXIDE desktop shell (RDS) - a Wayland desktop shell built with Quickshell";

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

      buildRoxidePkgs = pkgs: {
        RoxideDesktopShell = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        quickshell = quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };

      mkModuleWithRoxidePkgs =
        modulePath:
        args@{ pkgs, ... }:
        {
          imports = [
            (import modulePath (args // { roxidePkgs = buildRoxidePkgs pkgs; }))
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
              #revSuffix = "_" + (self.shortRev or "dirty");
            in
            "${cleanVersion}${dateSuffix}";

          coreSrc = ./core;
          cargoLockFile = coreSrc + "/Cargo.lock";

          qtPackages = qmlPkgs pkgs;
        in
        {
          RoxideDesktopShell = pkgs.lib.makeOverridable (
            {
              extraQtPackages ? [ ],
            }:
            (pkgs.rustPlatform.buildRustPackage.override { }) (
              let
                roxidePkgs = pkgs;
              in
              {
                inherit version;
                pname = "RoxideDesktopShell";
                src = coreSrc;
                cargoLock.lockFile = cargoLockFile;

                nativeBuildInputs = with roxidePkgs; [
                  pkg-config
                  makeWrapper
                ];

                buildInputs = with roxidePkgs; [
                  openssl
                  dbus
                ];

                postInstall = ''
                  mkdir -p $out/share/quickshell/RoxideDesktopShell
                  cp -r ${./quickshell}/. $out/share/quickshell/RoxideDesktopShell/

                  wrapProgram $out/bin/roxide \
                    --add-flags "-c $out/share/quickshell/RoxideDesktopShell" \
                    --prefix "NIXPKGS_QT6_QML_IMPORT_PATH" ":" "${
                      mkQmlImportPath roxidePkgs (qtPackages ++ extraQtPackages)
                    }" \
                    --prefix "QT_PLUGIN_PATH" ":" "${mkQtPluginPath roxidePkgs (qtPackages ++ extraQtPackages)}"
                '';

                meta = {
                  description = "Wayland desktop shell built with Quickshell";
                  homepage = "https://github.com/me-osano/RoxideDesktopShell";
                  license = pkgs.lib.licenses.mit;
                  mainProgram = "roxide";
                  platforms = pkgs.lib.platforms.linux;
                };
              }
            )
          ) { };

          quickshell = quickshell.packages.${system}.default;

          default = self.packages.${system}.RoxideDesktopShell;
        }
      );

      homeModules.default = mkModuleWithRoxidePkgs ./distro/nixos/home-module.nix;

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
