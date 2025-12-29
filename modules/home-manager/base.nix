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
    };
}
