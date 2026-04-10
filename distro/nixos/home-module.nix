{
  config,
  lib,
  roxidePkgs,
  ...
}:

let
  cfg = config.programs.roxide-desktop-shell;
in
{
  options.programs.roxide-desktop-shell = {
    enable = lib.mkEnableOption "ROXIDE desktop shell";
    
    package = lib.mkPackageOption roxidePkgs "RoxideDesktopShell" {
      extraDescription = "The RoxideDesktopShell package to use (defaults to be built from source)";
    };

    quickshell = {
      package = lib.mkPackageOption roxidePkgs "quickshell" {
        extraDescription = "The quickshell package to use";
      };
    };

    logLevel = lib.mkOption {
      type = lib.types.str;
      default = "info";
      description = "Log level for roxide-desktop-shell";
    };

    systemd = {
      enable = lib.mkEnableOption "ROXIDE systemd startup";
      restartIfChanged = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Auto-restart RoxideDesktopShell service when package changes";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."RoxideDesktopShell/quickshell".source = ../../quickshell;

    systemd.user.services.roxide = {
      Unit = {
        Description = "ROXIDE desktop shell daemon";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/roxide";
        Restart = "on-failure";
        RestartSec = "3s";
        Environment = [ "ROXIDE_LOG=${cfg.logLevel}" ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
