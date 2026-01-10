{
  inputs,
  ...
}:
{
  flake.modules.homeManager.heroku =
    {
      config,
      pkgs,
      ...
    }:
    let
      docker-compose-alias = pkgs.writeShellApplication {
        name = "docker-compose";
        text = ''
          ${pkgs.podman-compose}/bin/podman-compose "$@"
        '';
      };
      heroku-pg-import = pkgs.writeShellApplication {
        name = "heroku-postgres-import";
        text = ''
          pg_user=postgres
          # prefix="${pkgs.docker-compose}/bin/docker-compose exec -T postgres"
          prefix="podman-compose exec -T postgres"

          if [ -f "flake.nix" ]; then
            if grep -q devenv < flake.nix
            then
              pg_user="$USER"
              prefix=""
            fi
          fi

          $prefix psql -U "$pg_user" -d app_dev -c "CREATE SCHEMA IF NOT EXISTS heroku_ext;"

          # NOTE: pg_restore arguments that were removed to also run with devenv: --exit-on-error --if-exists
          $prefix pg_restore --verbose --clean --no-acl --no-owner -U "$pg_user" -d app_dev < latest.dump
        '';
      };
    in
    {
      home.packages = builtins.attrValues { inherit (pkgs) heroku; } ++ [
        docker-compose-alias
        heroku-pg-import
      ];

      home.sessionVariables = {
        HEROKU_ORGANIZATION = "coffeeandcode";
      };
    };
}
