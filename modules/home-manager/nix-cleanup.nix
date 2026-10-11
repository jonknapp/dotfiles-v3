{ inputs, ... }:
{
  flake.modules.homeManager.nix-cleanup =
    { pkgs, ... }:
    let
      nixCleanup = pkgs.writeShellApplication {
        name = "nix-cleanup";
        runtimeInputs = [
          pkgs.home-manager
          pkgs.nix
        ];
        text = ''
          read -r -p "Run Nix cleanup and remove old generations? [y/N] " answer
          case "$answer" in
            y|Y|yes|YES)
              ;;
            *)
              echo "Cleanup cancelled."
              exit 0
              ;;
          esac

          home-manager expire-generations "-30 days"
          nix profile wipe-history --older-than 30d
          nix-collect-garbage
        '';
      };
    in
    {
      home.packages = [ nixCleanup ];
    };
}
