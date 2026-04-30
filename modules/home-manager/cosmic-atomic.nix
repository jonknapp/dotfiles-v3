{
  inputs,
  ...
}:
{
  flake.modules.homeManager.cosmic-atomic =
    {
      config,
      pkgs,
      ...
    }:
    {
      imports = with inputs.self.modules.homeManager; [
        nixToolbox
      ];

      home.homeDirectory = "/var/home/${config.home.username}";

      programs.nixToolbox.enable = true;
    };
}
