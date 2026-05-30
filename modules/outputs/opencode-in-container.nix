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

          mkdir -p "$HOME/.config/opencode" "$HOME/.local/share/opencode"

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
            -v "$HOME/.config/opencode:/root/.config/opencode" \
            -v "$HOME/.local/share/opencode:/root/.local/share/opencode" \
            -w /workspace ghcr.io/anomalyco/opencode:1.14.48 "$@"
        '';
      };
    };
}
