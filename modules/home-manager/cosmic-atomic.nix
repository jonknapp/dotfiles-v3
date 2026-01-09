{
  inputs,
  ...
}:
{
  flake.modules.homeManager.cosmicAtomic =
    {
      config,
      pkgs,
      ...
    }@args:
    {
      imports =
        with inputs.self.modules.homeManager;
        [
          nixToolbox
        ]
        ++ [
          (import ../../programs/nix-toolbox.nix (args // { inherit inputs; }))
        ];

      home.homeDirectory = "/var/home/${config.home.username}";
    };
}
