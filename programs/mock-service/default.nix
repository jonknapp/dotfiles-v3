{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Python environment for StatusNotifierItem (SNI) tray
  trayPython = pkgs.python3.withPackages (ps: [
    ps.dbus-python
    ps.pygobject3 # provides gi.repository.GLib for the D-Bus main loop
  ]);

  # StatusNotifierItem tray icon implemented directly over D-Bus.
  # No GTK, no Xorg — works natively on Wayland with any SNI-compatible panel.
  #
  # Protocol references:
  #   https://www.freedesktop.org/wiki/Specifications/StatusNotifierItem/
  #   https://freedesktop.org/wiki/Specifications/StatusNotifierItem/StatusNotifierItem/
  trayScript = ./tray.py;

  # Wrap the tray script into a proper bin so it is on PATH inside the container
  trayBin = pkgs.writeShellScriptBin "mock-service-tray" ''
    exec ${trayPython}/bin/python3 ${trayScript} "$@"
  '';

  # The mock service loop as a bin so toolbox can find it by name on PATH
  mockServiceBin = pkgs.writeShellScriptBin "mock-service-run" ''
    while true; do
      echo "mock-service heartbeat $(date --iso-8601=seconds)" \
        | ${pkgs.systemd}/bin/systemd-cat --identifier=mock-service --priority=info
      sleep 10
    done
  '';

in
{
  home.packages = [
    trayBin
    mockServiceBin
  ];

  # -----------------------------------------------------------------
  # Mock long-lived service
  # Loops forever: sleeps 10 s then logs a heartbeat via systemd-cat.
  # ExecStart uses toolbox so the binary is found in the Nix profile
  # inside the container; systemd-cat is on the host on Fedora Atomic.
  # -----------------------------------------------------------------
  systemd.user.services.mock-service = {
    Unit = {
      Description = "Mock long-lived service (heartbeat every 10 s)";
    };

    Service = {
      Type = "simple";
      ExecStart = "toolbox --container ${config.programs.nixToolbox.containerName} run mock-service-run";
      Restart = "on-failure";
    };
  };

  # -----------------------------------------------------------------
  # Tray icon service
  # Starts after tray.target so the system tray is available.
  # -----------------------------------------------------------------
  systemd.user.services.mock-service-tray = {
    Unit = {
      Description = "System tray icon for mock-service";
      Requires = [ "tray.target" ];
      After = [ "tray.target" ];
    };

    Service = {
      ExecStart = ''
        toolbox --container ${config.programs.nixToolbox.containerName} run mock-service-tray
      '';
      Type = "exec";
      Restart = "on-failure";
      RestartSec = "3s";
      # WAYLAND_DISPLAY is inherited from the systemd user manager environment,
      # populated by dbus-update-activation-environment --all --systemd in bash.nix.
      PassEnvironment = [ "WAYLAND_DISPLAY" ];
    };

    Install = {
      WantedBy = [ "tray.target" ];
    };
  };

  # -----------------------------------------------------------------
  # Desktop entry — lets the COSMIC launcher start the tray manually
  # -----------------------------------------------------------------
  xdg.desktopEntries.mock-service-tray = {
    name = "Mock Service";
    exec = "systemctl --user start --no-block mock-service-tray.service";
    terminal = false;
    categories = [ "Utility" ];
    icon = "application-x-executable";
    comment = "Start/stop the mock service from the system tray";
  };
}
