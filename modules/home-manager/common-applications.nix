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
        chromium
        direnv
        discord
        fonts
        git
        heroku
        opencode
        ssh
        starship
        sublime-merge
        tailscale
        vscode
        vykar
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
