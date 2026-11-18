{ inputs, ... }:
{
  # Demo tray + service. Not part of common-applications; import
  # `mock-service` in a host module to use it directly on the host (e.g.
  # megaman). nix-toolbox hosts (e.g. zero) get it automatically below.
  flake.modules.homeManager.mock-service = {
    imports = [ ../../programs/mock-service/default.nix ];
  };

  flake.modules.homeManager.nix-toolbox =
    {
      config,
      ...
    }:
    {
      imports = [ inputs.self.modules.homeManager.mock-service ];

      # Run the binaries inside the toolbox container (they are only on PATH
      # there; Nix store paths don't exist on the host).
      systemd.user.services.mock-service.Service.ExecStart =
        "toolbox --container ${config.programs.nixToolbox.containerName} run mock-service-run";

      systemd.user.services.mock-service-tray.Service.ExecStart = ''
        toolbox --container ${config.programs.nixToolbox.containerName} run mock-service-tray
      '';
    };
}
