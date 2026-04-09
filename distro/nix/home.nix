{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = [
    pkgs.rustiq-shell
  ];

  xdg.configFile."rustiq-shell/quickshell".source = ../../quickshell;

  systemd.user.services.rustiq-shell = {
    Unit = {
      Description = "RUSTIQ desktop shell daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.rustiq-shell}/bin/rustiq-shell daemon";
      Restart = "on-failure";
      RestartSec = "3s";
      Environment = [ "RUSTIQ_LOG=info" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
