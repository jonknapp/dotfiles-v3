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

      home.sessionVariables = {
        # https://github.com/pop-os/cosmic-comp/issues/2336
        COSMIC_DISABLE_DIRECT_SCANOUT = "y";
      };

      programs.nixToolbox.enable = true;
    };
}
