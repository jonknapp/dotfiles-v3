{
  inputs,
  ...
}:
{
  # A Nix library to create wrapped executables via the module system
  # https://github.com/Lassulus/wrappers

  flake-file.inputs = {
    wrappers = {
      url = "github:lassulus/wrappers";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
