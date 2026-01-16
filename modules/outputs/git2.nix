{
  inputs,
  ...
}:
let
  wrappedGit =
    pkgs:
    inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.git;
      runtimeInputs = [ pkgs._1password-gui ];
      env = {
        SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
      };
      preHook = ''
        setsid 1password --silent </dev/null >/dev/null 2>&1 &
        sleep 1
      '';
    };
in
{
  perSystem =
    { pkgs, system, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate =
          pkg:
          builtins.elem (pkgs.lib.getName pkg) [
            "1password"
          ];
      };
    in
    {
      apps.git2 = {
        meta.description = "git2 + 1password ssh key support";
        type = "app";
        program = wrappedGit pkgs;
      };
    };
}
