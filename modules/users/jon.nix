{
  inputs,
  ...
}:
let
  email = "jon@coffeeandcode.com";
  fullname = "Jonathan Knapp";
  username = "jon";
in
{
  flake.modules.homeManager.jon =
    { pkgs, ... }:
    {
      home.username = "${username}";

      programs.git = {
        settings = {
          user.email = email;
          user.name = fullname;
        };
        signing = {
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOwN+ZE4LIFZ9im8j/M1OFEAvyV5Prkzxi3Y1fml2RLH";
          signByDefault = true;
        };
      };
    };
}
