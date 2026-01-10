{ inputs, ... }:
{
  flake.modules.homeManager.common-applications =
    {
      pkgs,
      ...
    }:
    {
      imports = with inputs.self.modules.homeManager; [
        _1password
        bash
        borg
        chromium
        direnv
        discord
        fonts
        git
        heroku
        ssh
        starship
        sublime-merge
        tailscale
        vscode
        xdg
      ];

      home.packages = with pkgs; [
        fd
        nh
        nixfmt
        podman-compose
      ];
    };
}
