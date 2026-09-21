{ ... }:
{
  # Add Cachix binary caches so Nix pulls pre-built derivations from your cache
  # instead of building locally.
  #
  # Replace the example substituter URL and public key with values from your
  # Cachix cache dashboard (https://app.cachix.org).
  #
  # After changing these values, regenerate flake.nix:
  #   nix run .#write-flake

  flake-file.nixConfig = {
    extra-substituters = [
      "https://robots.cachix.org"
    ];
    extra-trusted-public-keys = [
      "robots.cachix.org-1:HJAwawmBJ8NEvRI6DeibrmCO+9aAW3imFNRvI3dBrRA="
    ];
  };
}
