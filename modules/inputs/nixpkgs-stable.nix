{
  inputs,
  ...
}:
{
  flake-file.inputs = {
    nixpkgs-stable = {
      url = "github:nixos/nixpkgs/nixos-26.05";
    };
  };
}
