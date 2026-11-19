{
  inputs,
  ...
}:
{
  # One-time, idempotent host setup (binary cache trust, onepassword-cli group,
  # vykar passphrase credential + config).
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
        # intentionally taken from the host. vykar, op and systemd-creds come
        # from the user's environment (home-manager / host); the vykar step is
        # skipped until they exist.
        runtimeEnv = {
          SETUP_CACHE_SUBSTITUTER = inputs.self.lib.cachix.substituter;
          SETUP_CACHE_PUBLIC_KEY = inputs.self.lib.cachix.trustedPublicKey;
        };
        text = builtins.readFile ../../scripts/setup-new-machine.sh;
      };
    };
}
