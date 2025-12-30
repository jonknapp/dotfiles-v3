{ inputs, ... }:

{
  flake.modules.homeManager.commonApplications =
    {
      config,
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        git
      ];

      xdg.configFile."ssh/allowed_signers".text =
        ''${config.programs.git.settings.user.email} namespaces="git" ${config.programs.git.signing.key}'';

      programs.git = {
        enable = true;

        settings = {
          aliases = {
            pretty = "log --graph --decorate --all --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
            sha = ''log --format="%H" --max-count=1'';
          };
          user.email = "jon@coffeeandcode.com";
          user.name = "Jonathan Knapp";

          advice.skippedCherryPicks = false;
          # core.editor = "${pkgs.vscode}/bin/code --wait";
          diff.tool = "bc";
          difftool.bc.trustExitCode = true;
          difftool.prompt = false;
          gpg.format = "ssh";
          gpg.ssh.allowedSignersFile = "~/${config.xdg.configFile."ssh/allowed_signers".target}";
          help.autocomplete = 1;
          help.autocorrect = 20;
          init.defaultBranch = "main";
          pull.ff = "only";
          push.autoSetupRemote = true;
          push.default = "simple";
        };

        ignores = [
          ".byebug_history"
          ".DS_Store"
          ".elixir_ls/"
          ".vscode/"
          "npm-debug.log"
          "project.code-workspace"
        ];

        signing = {
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOwN+ZE4LIFZ9im8j/M1OFEAvyV5Prkzxi3Y1fml2RLH";
          signByDefault = true;
        };
      };
    };
}
