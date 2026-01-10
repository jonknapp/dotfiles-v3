{
  inputs,
  lib,
  ...
}:
{
  flake.modules.homeManager.fonts =
    {
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        # nerd-fonts.fira-code # broken in smerge?
        noto-fonts-color-emoji
        noto-fonts-monochrome-emoji
      ];

      fonts.fontconfig.enable = lib.mkDefault false;
    };

  flake.modules.homeManager.nixToolbox = {
    xdg.configFile."fontconfig/fonts.conf".text = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <dir>~/.local/share/nix-toolbox-profile/share/fonts/</dir>
      </fontconfig>
    '';
  };
}
