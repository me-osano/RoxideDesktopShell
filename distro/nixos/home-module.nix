{
  config,
  lib,
  rustiqPkgs,
  ...
}:

let
  cfg = config.programs.rustiq-shell;
in
{
  options.programs.rustiq-shell = {
    enable = lib.mkEnableOption "RUSTIQ desktop shell";
    
    package = lib.mkPackageOption rustiqPkgs "rustiq-shell" {
      extraDescription = "The RustiqDesktopShell package to use (defaults to be built from source)";
    };

    quickshell = {
      package = lib.mkPackageOption rustiqPkgs "quickshell" {
        extraDescription = "The quickshell package to use";
      };
    };

    logLevel = lib.mkOption {
      type = lib.types.str;
      default = "info";
      description = "Log level for rustiq-shell";
    };

    systemd = {
      enable = lib.mkEnableOption "RUSTIQ systemd startup";
      restartIfChanged = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Auto-restart rustiq-shell service when package changes";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."rustiq-shell/quickshell".source = ../../quickshell;

    systemd.user.services.rustiq = {
      Unit = {
        Description = "RUSTIQ desktop shell daemon";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/rustiq";
        Restart = "on-failure";
        RestartSec = "3s";
        Environment = [ "RUSTIQ_LOG=${cfg.logLevel}" ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
