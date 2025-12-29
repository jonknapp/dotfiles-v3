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
      imports = with inputs.self.modules.homeManager; [
        atomic
      ];

      programs.nixToolbox.enable = true;

      home.homeDirectory = "/var/home/${config.home.username}";
    };
}
