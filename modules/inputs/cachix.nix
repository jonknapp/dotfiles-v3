{ ... }:
let
  substituter = "https://robots.cachix.org";
  trustedPublicKey = "robots.cachix.org-1:HJAwawmBJ8NEvRI6DeibrmCO+9aAW3imFNRvI3dBrRA=";
in
{
  # Add the robots Cachix cache so Nix pulls pre-built derivations instead of
  # building locally.
  #
  # The public key must be trusted on the host in /etc/nix/nix.conf (see
  # README). It is intentionally not sent from the flake: `trusted-public-keys`
  # is a restricted setting, so for untrusted users on a multi-user install it
  # is ignored and only produces a warning. `extra-substituters` is used so the
  # user's existing substituters (incl. cache.nixos.org) are preserved.
  #
  # After changing these values, regenerate flake.nix:
  #   nix run .#write-flake

  config = {
    flake.lib = {
      cachix = {
        inherit substituter trustedPublicKey;
      };
    };

    flake-file.nixConfig = {
      extra-substituters = [ substituter ];
    };
  };
}
