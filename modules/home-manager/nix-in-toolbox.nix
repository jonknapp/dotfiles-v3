{
  inputs,
  ...
}:
{
  flake.modules.homeManager.nix-in-toolbox =
    {
      config,
      pkgs,
      ...
    }:
    {
      imports = with inputs.self.modules.homeManager; [
        nixToolbox
      ];

      programs.nixToolbox.enable = true;
    };
}
