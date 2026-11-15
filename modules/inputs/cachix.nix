{ ... }:
let
  substituter = "https://robots.cachix.org";
  trustedPublicKey = "robots.cachix.org-1:HJAwawmBJ8NEvRI6DeibrmCO+9aAW3imFNRvI3dBrRA=";
in
{
  # Add Cachix binary caches so Nix pulls pre-built derivations from your cache
  # instead of building locally.
  #
  # Replace the example substituter URL and public key with values from your
  # Cachix cache dashboard (https://app.cachix.org).
  #
  # After changing these values, regenerate flake.nix:
  #   nix run .#write-flake

  config = {
    flake.lib = {
      cachix = {
        inherit substituter trustedPublicKey;
      };
    };

    # The public key is configured on the host in /etc/nix/nix.conf via
    # `trusted-public-keys`. Sending it from the client is a restricted setting
    # for untrusted users and only produces warnings.
    flake-file.nixConfig = {
      extra-substituters = [ substituter ];
    };
  };
}
