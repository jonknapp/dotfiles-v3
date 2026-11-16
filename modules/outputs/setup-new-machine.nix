{
  inputs,
  ...
}:
{
  # One-time, idempotent host setup (binary cache trust, onepassword-cli group).
  #   nix run .#setup-new-machine
  perSystem =
    { pkgs, ... }:
    {
      packages.setup-new-machine = pkgs.writeShellApplication {
        name = "setup-new-machine";
        runtimeInputs = with pkgs; [
          coreutils
          diffutils
          gawk
          gnugrep
        ];
        # sudo, systemctl, launchctl, getent, groupadd and usermod are
        # intentionally taken from the host.
        runtimeEnv = {
          SETUP_CACHE_SUBSTITUTER = inputs.self.lib.cachix.substituter;
          SETUP_CACHE_PUBLIC_KEY = inputs.self.lib.cachix.trustedPublicKey;
        };
        text = builtins.readFile ../../scripts/setup-new-machine.sh;
      };
    };
}
