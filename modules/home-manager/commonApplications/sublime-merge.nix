{
  inputs,
  ...
}:
{
  flake.modules.homeManager.commonApplications =
    {
      config,
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [ sublime-merge ];

      programs.git.settings = {
        merge.tool = "smerge";
        mergetool = {
          smerge = {
            cmd = ''smerge mergetool "$BASE" "$LOCAL" "REMOTE" -o "$MERGED"'';
            trustExitCode = true;
          };
        };
      };
    };

  flake.modules.homeManager.nixToolbox =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.packages = [
        (lib.hiPrio (
          pkgs.runCommand "sublime-merge-desktop-modify" { } ''
            mkdir -p $out/share/applications
            substitute ${pkgs.sublime-merge}/share/applications/sublime_merge.desktop $out/share/applications/sublime_merge.desktop \
              --replace-fail "Exec=sublime_merge" "Exec=toolbox run --container ${config.programs.nixToolbox.containerName} sublime_merge"
          ''
        ))

      ];
    };
}
