{
  inputs,
  ...
}:
{
  flake.modules.homeManager.fedora-atomic =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.homeDirectory = "/var/home/${config.home.username}";

      # Nix on a non-NixOS distro (e.g. Fedora Atomic on megaman / zero): adds
      # the Nix profile's share dir to XDG_DATA_DIRS so desktop launchers and
      # icons are found, and sets up locale, terminfo and GPU drivers for Nix
      # programs.
      targets.genericLinux.enable = true;
    };
}
