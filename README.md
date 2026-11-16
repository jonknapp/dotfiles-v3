- https://github.com/Doc-Steve/dendritic-design-with-flake-parts
- https://github.com/thrix/nix-toolbox

On a new machine, run the setup script first (see [New machine setup](#new-machine-setup)):

```sh
nix run .#setup-new-machine
nix run home-manager/master -- switch --flake .#jon@megaman
nix run home-manager/master -- switch --flake .#jon@zero
```

- If you add new files, make sure to `git add` them so they are included as modules.
- If you adjust any flake inputs, make sure to run `nix run .#write-flake` to rebuild `flake.nix`

## New machine setup

`nix run .#setup-new-machine` performs one-time host setup (currently: binary
cache trust, below). It detects a multi-user (daemon) vs single-user Nix install
and edits the matching `nix.conf`. It is idempotent and safe to re-run:

- every change is shown as a diff and confirmed before writing; `sudo` is only
  used when the target file is not writable (e.g. `/etc/nix/nix.conf`)
- existing values are kept; it asks before adding to an existing line or
  replacing a different value for the same key (e.g. a rotated public key)
- the previous file is backed up as `nix.conf.bak-<timestamp>`
- files managed by NixOS / nix-darwin / home-manager (symlinks) are left alone
  and the equivalent `nix.settings` are printed instead

Options: `--dry-run` (show changes only), `--yes` (accept defaults),
`--mode daemon|single-user` (override detection). The script lives in
`scripts/setup-new-machine.sh`; add further steps there.

## Binary cache trust

`flake.nix` requests the `robots` Cachix cache via `nixConfig`
(`extra-substituters`). It intentionally does not send the cache's public key:
`trusted-public-keys` is a restricted setting, so on a multi-user install an
untrusted user only gets a warning:

```
warning: ignoring the client-specified setting 'trusted-public-keys', because it is a restricted setting and you are not a trusted user
```

Instead, trust the cache once per machine with `nix run .#setup-new-machine`, or
manually as described below. Without the key,
paths from the cache fail signature verification and Nix falls back to
`cache.nixos.org` or building locally.

### Single-user install

There is no daemon, so your user config is applied directly. Add to
`~/.config/nix/nix.conf`:

```ini
extra-substituters = https://robots.cachix.org
extra-trusted-public-keys = robots.cachix.org-1:HJAwawmBJ8NEvRI6DeibrmCO+9aAW3imFNRvI3dBrRA=
```

No restart is needed. Verify with `nix config show substituters` and
`nix config show trusted-public-keys`.

### Multi-user install (nix-daemon)

Restricted settings from untrusted users are ignored by the daemon, so configure
the cache in `/etc/nix/nix.conf`. Without this, untrusted users also see
`warning: ignoring untrusted substituter 'https://robots.cachix.org'`:

```ini
extra-trusted-substituters = https://robots.cachix.org
extra-trusted-public-keys = robots.cachix.org-1:HJAwawmBJ8NEvRI6DeibrmCO+9aAW3imFNRvI3dBrRA=
```

`extra-trusted-substituters` allows (but does not force) clients to use the
cache, which this flake requests via `extra-substituters`. Use
`extra-substituters` instead to enable the cache for every build on the host.
The `extra-` forms append to existing values rather than replacing them. Then restart the daemon:

```sh
sudo systemctl restart nix-daemon
```

Verify with `nix config show trusted-substituters` and `nix config show
trusted-public-keys`. On NixOS, set the same values via
`nix.settings.trusted-substituters` / `nix.settings.trusted-public-keys`
instead of editing `nix.conf` (NixOS merges these lists, so no `extra-` prefix
is needed).

The `nix-toolbox` home-manager wrapper likewise only sends `extra-substituters`.

## TODO

- [ ] check out [alternative wrapper lib](https://birdeehub.github.io/nix-wrapper-modules/home.html)
