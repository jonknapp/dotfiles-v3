{
  inputs,
  ...
}:
{
  flake.modules.homeManager.commonApplications =
    {
      config,
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        fd
        nh
        nixfmt
        podman-compose
      ];
    };
}
