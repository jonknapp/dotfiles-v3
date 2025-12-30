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
        nerd-fonts.fira-code
        noto-fonts-color-emoji
        noto-fonts-monochrome-emoji
      ];

      fonts.fontconfig = {
        enable = true; # Ensures fonts are correctly configured for applications
        # configFile = {
        #   emoji = {
        #     enable = true;
        #     label = "noto-emoji-disable";
        #     priority = 90;
        #     text = ''
        #       <?xml version="1.0"?>
        #       <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        #       <fontconfig>
        #         <selectfont>
        #           <rejectfont>
        #             <glob>/usr/share/fonts/google-noto-vf/NotoSans*.ttf</glob>
        #             <glob>/run/host/usr/share/fonts/google-noto-emoji-fonts/NotoEmoji-Regular.ttf</glob>
        #             <glob>/run/host/usr/share/fonts/google-noto-color-emoji-fonts/Noto-COLRv1.ttf</glob>
        #             <glob>/usr/share/fonts/google-noto-emoji-fonts/NotoEmoji-Regular.ttf</glob>
        #             <glob>/usr/share/fonts/google-noto-color-emoji-fonts/Noto-COLRv1.ttf</glob>
        #           </rejectfont>
        #         </selectfont>
        #       </fontconfig>
        #     '';
        #   };
        # };
        # defaultFonts = {
        #   emoji = [
        #     "Noto Emoji"
        #     "Noto Color Emoji"
        #   ];
        #   #   #   monospace = "Fira Code";
        #   #   #   sansSerif = "Noto Sans";
        #   #   #   serif = "Noto Serif";
        # };
      };
    };
}
