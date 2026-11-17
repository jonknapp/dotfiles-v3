{
  inputs,
  ...
}:
{
  # Firefox binary comes from nix; profiles and extensions are intentionally
  # left unmanaged (stored in ~/.mozilla/firefox as usual).
  flake.modules.homeManager.firefox =
    {
      config,
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [ firefox ];

      # Hide the Fedora RPM Firefox launcher so only the nix one shows up.
      # Both share ~/.mozilla, so mixing versions risks profile downgrade errors.
      xdg.dataFile."applications/org.mozilla.firefox.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Firefox (Fedora)
        NoDisplay=true
        Hidden=true
      '';

      xdg.mimeApps.defaultApplications = {
        "text/html" = "firefox.desktop";
        "application/xhtml+xml" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "x-scheme-handler/about" = "firefox.desktop";
        "x-scheme-handler/unknown" = "firefox.desktop";
      };
    };
}
