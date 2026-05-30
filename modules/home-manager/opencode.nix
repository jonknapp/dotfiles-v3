{
  inputs,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.opencode-in-container = pkgs.writeShellApplication {
        name = "opencode-in-container";
        text = ''
          printf "Running opencode in a container with %s as workspace. Continue? (y/N) " "$(pwd)"

          XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
          XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"

          mkdir -p "$XDG_CONFIG_HOME/opencode" "$XDG_DATA_HOME/opencode"

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
            -v "$XDG_CONFIG_HOME/opencode:/root/.config/opencode" \
            -v "$XDG_DATA_HOME/opencode:/root/.local/share/opencode" \
            -w /workspace ghcr.io/anomalyco/opencode:1.14.48 "$@"
        '';
      };
    };

  flake.modules.homeManager.opencode =
    {
      pkgs,
      ...
    }:
    {
      home.packages = [
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencode-in-container
      ];
    };
}
