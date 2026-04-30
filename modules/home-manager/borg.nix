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

      programs.ssh = {
        matchBlocks = {
          "*.repo.borgbase.com" = {
            identityFile = "~/.ssh/borg.pub";
          };
        };
      };
    };
}
