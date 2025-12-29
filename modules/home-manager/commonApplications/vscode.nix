{
  inputs,
  ...
}:
{
  flake.modules.homeManager.commonApplications =
    {
      config,
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        nerd-fonts.fira-code
        noto-fonts-color-emoji
        noto-fonts-monochrome-emoji
        vscode
      ];

      home.sessionVariables.EDITOR = "code --wait";

      xdg.mimeApps.defaultApplications = {
        "text/*" = "code.desktop";
      };
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
          pkgs.runCommand "code-desktop-modify" { } ''
            mkdir -p $out/share/applications
            substitute ${pkgs.vscode}/share/applications/code.desktop $out/share/applications/code.desktop \
              --replace-fail "Exec=code" "Exec=toolbox run --container ${config.programs.nixToolbox.containerName} code"
          ''
        ))
        (lib.hiPrio (
          pkgs.runCommand "code-url-handler-desktop-modify" { } ''
            mkdir -p $out/share/applications
            substitute ${pkgs.vscode}/share/applications/code-url-handler.desktop $out/share/applications/code-url-handler.desktop \
              --replace-fail "Exec=code" "Exec=toolbox run --container ${config.programs.nixToolbox.containerName} code"
          ''
        ))
      ];
    };
}
