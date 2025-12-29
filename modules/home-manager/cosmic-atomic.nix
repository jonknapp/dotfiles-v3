{
  inputs,
  ...
}:
{
  flake.modules.homeManager.cosmicAtomic =
    {
      config,
      ...
    }:
    {
      imports = [
        ../../programs/nix-toolbox.nix
      ];

      home.homeDirectory = "/var/home/${config.home.username}";
    };
}
