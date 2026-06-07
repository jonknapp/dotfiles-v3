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

          printf "Persist the container after use? (y/N) "
          read -r persist

          PERSIST=0
          if [ "$persist" = "Y" ] || [ "$persist" = "y" ]; then
            PERSIST=1
          fi

          # Derive a clean name from the current folder name:
          # lowercase, replace any run of non-alphanumeric chars with a hyphen,
          # strip leading/trailing hyphens.
          FOLDER_NAME="$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/-/g' | sed 's/^-\+//;s/-\+$//')"

          # Default: ephemeral name with datetime prefix; include --rm.
          CONTAINER_NAME="opencode-$(date +%Y%m%d%H%M%S)-$FOLDER_NAME"
          extra_flags=("--rm")

          if [ "$PERSIST" = "1" ]; then
            CONTAINER_NAME="opencode-''${name_input:-$FOLDER_NAME}"
            extra_flags=()
            printf "Container name [%s]: " "$CONTAINER_NAME"
            read -r name_input

            # If a container with this name already exists, restart it instead.
            if podman container exists "$CONTAINER_NAME" 2>/dev/null; then
              printf "Container '%s' already exists. Restarting it...\n" "$CONTAINER_NAME"
              podman start --attach --interactive "$CONTAINER_NAME"
              exit $?
            fi
          fi

          podman run --interactive --tty "''${extra_flags[@]}" \
            --name "$CONTAINER_NAME" \
            --cap-add=SYS_ADMIN,MKNOD,NET_ADMIN,SETUID,SETGID \
            --security-opt label=disable \
            --security-opt seccomp=unconfined \
            --device /dev/fuse \
            --volume "$(pwd):/workspace" \
            --volume "$XDG_CONFIG_HOME/opencode:/root/.config/opencode" \
            --volume "$XDG_DATA_HOME/opencode:/root/.local/share/opencode" \
            --workdir /workspace ghcr.io/anomalyco/opencode:latest "$@"
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
