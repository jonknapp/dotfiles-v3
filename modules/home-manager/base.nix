{
  inputs,
  ...
}:
{
  flake.modules.homeManager.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.homeDirectory = lib.mkDefault (
        if pkgs.stdenv.isDarwin then
          (lib.mkForce "/Users/${config.home.username}")
        else
          "/home/${config.home.username}"
      );
      home.stateVersion = lib.mkDefault "25.11";

      nixpkgs.config.allowUnfree = lib.mkDefault true;

      programs.home-manager.enable = lib.mkDefault true;

      # Nix on a non-NixOS distro (e.g. Fedora Atomic on megaman / zero): adds
      # the Nix profile's share dir to XDG_DATA_DIRS so desktop launchers and
      # icons are found, and sets up locale, terminfo and GPU drivers for Nix
      # programs. Override with `false` on NixOS hosts.
      targets.genericLinux.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
    };
}
