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
      imports =
        with inputs.self.modules.homeManager;
        [
          nixToolbox
        ]
        ++ [
          ../../programs/nix-toolbox.nix
        ];

      home.homeDirectory = "/var/home/${config.home.username}";
    };
}
