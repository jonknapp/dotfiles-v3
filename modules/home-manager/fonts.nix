{
  inputs,
  lib,
  ...
}:
{
  # By default home-manager's fontconfig registers the Nix profile fonts with
  # the host directly (e.g. megaman, zero). The nix-toolbox module below
  # disables that and instead points fontconfig at fonts copied out of the
  # toolbox container by the nix-toolbox post-activation script, since the Nix
  # store paths referenced by home-manager's fontconfig files don't exist on the
  # host.
  #
  # COSMIC apps (cosmic-term etc.) don't use fontconfig for matching. Their
  # font loader (fontdb) reads ~/.config/fontconfig/fonts.conf first, then
  # /etc/fonts/fonts.conf, and when several fonts share a family name it uses
  # the first one loaded. Fedora ships "Noto Color Emoji" as a COLRv1 font,
  # which COSMIC can't render (emoji show as blank space), so we list the Nix
  # profile fonts in fonts.conf to make the Nix (CBDT) "Noto Color Emoji" win.
  # Without fonts.conf, home-manager's conf.d files are only reached after
  # /usr/share/fonts has already been loaded.
  flake.modules.homeManager.fonts =
    {
      config,
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

      xdg.configFile."fontconfig/fonts.conf".text = lib.mkDefault ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <dir>${config.home.profileDirectory}/share/fonts</dir>
        </fontconfig>
      '';
    };

  flake.modules.homeManager.nix-toolbox = {
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
