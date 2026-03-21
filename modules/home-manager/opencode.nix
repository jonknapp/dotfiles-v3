{
  inputs,
  ...
}:
{
  flake.modules.homeManager.opencode =
    {
      config,
      pkgs,
      ...
    }:
    let
      opencode-in-docker = pkgs.writeShellApplication {
        name = "opencode-in-docker";
        text = ''
          podman run -it --rm --privileged -v "$(pwd):/workspace" -v ~/.config/opencode:/home/opencode/.config/opencode -w /workspace ghcr.io/anomalyco/opencode "$@"
        '';
      };
    in
    {
      home.packages = [
        opencode-in-docker
      ];
    };
}
