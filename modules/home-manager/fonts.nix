{
  inputs,
  lib,
  ...
}:
{
  # By default home-manager's fontconfig registers the Nix profile fonts with
  # the host directly (e.g. megaman). The nixToolbox module below disables that
  # and instead points fontconfig at fonts copied out of the toolbox container
  # by the nix-toolbox post-activation script (e.g. zero), since the Nix store
  # paths referenced by home-manager's fontconfig files don't exist on the host.
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

      fonts.fontconfig.enable = lib.mkDefault true;
    };

  flake.modules.homeManager.nixToolbox = {
    fonts.fontconfig.enable = false;

    xdg.configFile."fontconfig/fonts.conf".text = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <dir>~/.local/share/nix-toolbox-profile/share/fonts/</dir>
      </fontconfig>
    '';
  };
}
