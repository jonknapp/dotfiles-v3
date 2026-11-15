- https://github.com/Doc-Steve/dendritic-design-with-flake-parts
- https://github.com/thrix/nix-toolbox

```sh
nix run home-manager/master -- switch --flake .#jon@megaman
nix run home-manager/master -- switch --flake .#jon@zero
```

- If you add new files, make sure to `git add` them so they are included as modules.
- If you adjust any flake inputs, make sure to run `nix run .#write-flake` to rebuild `flake.nix`

## Host setup: binary cache trust

`flake.nix` enables the `robots` Cachix cache via `nixConfig`. On a multi-user
Nix installation, substituters and public keys are restricted settings, so an
untrusted user gets:

```
warning: ignoring the client-specified setting 'trusted-public-keys', because it is a restricted setting and you are not a trusted user
warning: ignoring untrusted substituter 'https://robots.cachix.org', you are not a trusted user.
```

Home Manager cannot fix this because it is enforced by the Nix daemon. Configure
the cache once per host in `/etc/nix/nix.conf`. Because the key is trusted by the
daemon, the flake only needs to add the substituter; it intentionally does not
send `extra-trusted-public-keys` (doing so as an untrusted user only causes a
warning).

```ini
trusted-substituters = https://robots.cachix.org
trusted-public-keys = robots.cachix.org-1:HJAwawmBJ8NEvRI6DeibrmCO+9aAW3imFNRvI3dBrRA=
```

Then restart the daemon (needed for the setting to take effect):

```sh
sudo systemctl restart nix-daemon
```

Verify with `nix config show trusted-substituters` and `nix config show
trusted-public-keys`. On NixOS, set the same values via
`nix.settings.trusted-substituters` / `nix.settings.trusted-public-keys` instead
of editing `nix.conf`.

## TODO

- [ ] check out [alternative wrapper lib](https://birdeehub.github.io/nix-wrapper-modules/home.html)
