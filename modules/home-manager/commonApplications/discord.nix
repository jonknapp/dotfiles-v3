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
      home.packages = with pkgs; [ discord ];
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
          pkgs.runCommand "discord-desktop-modify" { } ''
            mkdir -p $out/share/applications
            substitute ${pkgs.discord}/share/applications/discord.desktop $out/share/applications/discord.desktop \
              --replace-fail "Exec=Discord" "Exec=toolbox run --container ${config.programs.nixToolbox.containerName} discord"
          ''
        ))
      ];
    };
}
