{
  inputs,
  ...
}:
{
  # Unprivileged tailscale: tailscaled runs as a systemd *user* service with
  # userspace networking (no TUN, no root) and a socket in $XDG_RUNTIME_DIR.
  # The systray is started on demand from the "Tailscale" desktop entry, which
  # also pulls in tailscaled. Since the daemon runs as the same user as the
  # client, no `tailscale set --operator` is needed.
  #
  # By default the Nix tailscale/tailscaled binaries run directly on the host
  # (e.g. megaman). The nixToolbox module below overrides ExecStart to run
  # them inside the toolbox container instead (e.g. zero).
  flake.modules.homeManager.tailscale =
    {
      lib,
      pkgs,
      ...
    }:
    let
      tailscaledArgs = "--tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1055 --socket=%t/tailscaled.sock";
    in
    {
      home.packages = with pkgs; [
        tailscale

        # point the CLI at the user tailscaled socket
        (lib.hiPrio (
          pkgs.stdenv.mkDerivation {
            pname = "wrapped-tailscale";
            version = "1.0";
            dontUnpack = true;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              mkdir -p $out/bin

              makeWrapper ${pkgs.tailscale}/bin/tailscale $out/bin/tailscale \
                --add-flags "--socket \$XDG_RUNTIME_DIR/tailscaled.sock"
            '';
          }
        ))

        # used by tailscale systray for clipboard access in wayland
        # https://tailscale.com/kb/1597/linux-systray#support-for-non-linux-desktops
        wl-clipboard
      ];

      systemd.user.services.tailscale-systray = {
        Unit = {
          Description = "Start tailscale systray";
          Requires = [
            "tailscaled.service"
            "tray.target"
          ];
          After = [
            "tailscaled.service"
            "tray.target"
          ];
        };

        Service = {
          ExecStart = lib.mkDefault "${pkgs.tailscale}/bin/tailscale --socket=%t/tailscaled.sock systray";
          Type = "exec";
        };
      };

      systemd.user.services.tailscaled = {
        Unit = {
          Description = "Start tailscaled with user networking";
          Wants = [ "network-pre.target" ];
          After = [
            "network-pre.target"
            "NetworkManager.service"
            "systemd-resolved.service"
          ];
          BindsTo = [ "tailscale-systray.service" ];
        };

        Service = {
          ExecStart = lib.mkDefault "${pkgs.tailscale}/bin/tailscaled ${tailscaledArgs}";
          ExecStopPost = lib.mkDefault "${pkgs.tailscale}/bin/tailscaled --socket=%t/tailscaled.sock --cleanup";
          Restart = "on-failure";
          RuntimeDirectory = "tailscale";
          RuntimeDirectoryMode = "0755";
          StateDirectory = "tailscale";
          StateDirectoryMode = "0700";
          CacheDirectory = "tailscale";
          CacheDirectoryMode = "0750";
          Type = "simple";
        };
      };

      xdg.desktopEntries = {
        tailscale-systray = {
          name = "Tailscale";
          exec = "systemctl --user start --no-block tailscale-systray.service";
          terminal = false;
          categories = [
            "Network"
          ];
          icon = "application-x-executable";
        };
      };
    };

  flake.modules.homeManager.nixToolbox =
    {
      config,
      ...
    }:
    {
      # Run the binaries inside the toolbox container (they are only on PATH
      # there).
      systemd.user.services.tailscale-systray.Service.ExecStart = ''
        toolbox --container ${config.programs.nixToolbox.containerName} run tailscale systray
      '';

      systemd.user.services.tailscaled.Service = {
        ExecStart = ''
          toolbox --container ${config.programs.nixToolbox.containerName} run tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1055 --socket=%t/tailscaled.sock
        '';
        ExecStopPost = "tailscaled --socket=%t/tailscaled.sock --cleanup";
      };
    };
}
