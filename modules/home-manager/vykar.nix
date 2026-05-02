{
  inputs,
  ...
}:
{
  flake-file.inputs = {
    vykar = {
      url = "github:borgbase/vykar/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  flake.modules.homeManager.vykar =
    {
      config,
      pkgs,
      ...
    }:
    {
      home.packages = [
        inputs.vykar.packages.${pkgs.stdenv.hostPlatform.system}.vykar
        inputs.vykar.packages.${pkgs.stdenv.hostPlatform.system}.vykar-gui
      ];
    };
}
