{
  inputs,
  ...
}:
{
  flake.modules.homeManager.chromium =
    {
      config,
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [ chromium ];
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
