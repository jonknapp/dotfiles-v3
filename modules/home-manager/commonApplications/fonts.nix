{
  inputs,
  ...
}:
{
  flake.modules.homeManager.commonApplications =
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

      fonts.fontconfig.enable = true;
    };
}
