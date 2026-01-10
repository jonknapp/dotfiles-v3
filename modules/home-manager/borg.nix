{
  inputs,
  ...
}:
{
  flake.modules.homeManager.borg =
    {
      config,
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        borgbackup

        # borg init --rsh="/usr/bin/ssh" -e repokey-blake2 ssh://xxx@xxx.repo.borgbase.com/./repo
        # need to set `--rsh"/usr/bin/ssh"` in Pika Backup to get it to work
        pika-backup
      ];
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
          pkgs.runCommand "chromium-browser-desktop-modify" { } ''
            mkdir -p $out/share/applications
            substitute ${pkgs.chromium}/share/applications/chromium-browser.desktop $out/share/applications/chromium-browser.desktop \
              --replace-fail "Exec=chromium" "Exec=toolbox run --container ${config.programs.nixToolbox.containerName} chromium"
          ''
        ))
      ];
    };
}
