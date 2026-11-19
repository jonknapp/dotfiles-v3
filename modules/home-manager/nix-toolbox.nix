{ ... }:
{
  # Run home-manager inside a Toolbx container on Fedora Atomic. Importing this
  # module enables it (no host currently does). Other features contribute their
  # toolbox-specific overrides to this same `nix-toolbox` module (collector
  # aspect), e.g. desktop entries that launch via `toolbox run`.
  flake.modules.homeManager.nix-toolbox = {
    imports = [ ../../programs/nix-toolbox.nix ];
  };
}
