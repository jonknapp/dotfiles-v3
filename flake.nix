# DO-NOT-EDIT. This file was auto-generated using github:denful/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  nixConfig = {
    extra-substituters = [ "https://robots.cachix.org" ];
    extra-trusted-public-keys = [ "robots.cachix.org-1:HJAwawmBJ8NEvRI6DeibrmCO+9aAW3imFNRvI3dBrRA=" ];
  };

  inputs = {
    flake-file.url = "github:denful/flake-file";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";
    vykar = {
      url = "github:borgbase/vykar/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wrappers = {
      url = "github:lassulus/wrappers";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
