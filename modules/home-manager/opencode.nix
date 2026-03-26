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
      opencode-in-container = pkgs.writeShellApplication {
        name = "opencode-in-container";
        text = ''
          printf "Running opencode in a container with %s as workspace. Continue? (y/N) " "$(pwd)"

          mkdir -p ${config.xdg.configHome}/opencode ${config.xdg.dataHome}/opencode

          read -r confirm
          if [ "$confirm" != "Y" ] && [ "$confirm" != "y" ]; then
            exit 1
          fi

          podman run -it --rm \
            --cap-add=SYS_ADMIN,MKNOD,NET_ADMIN,SETUID,SETGID \
            --security-opt label=disable \
            --security-opt seccomp=unconfined \
            --device /dev/fuse \
            -v "$(pwd):/workspace" \
            -v ${config.xdg.configHome}/opencode:/root/.config/opencode \
            -v ${config.xdg.dataHome}/opencode:/root/.local/share/opencode \
            -w /workspace ghcr.io/anomalyco/opencode "$@"
        '';
      };
    in
    {
      home.packages = [
        opencode-in-container
      ];
    };
}
