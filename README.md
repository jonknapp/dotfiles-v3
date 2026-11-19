# Home Manager configurations

- If you add new files, make sure to `git add` them so they are included as modules.
- If you adjust any flake inputs, make sure to run `nix run .#write-flake` to rebuild `flake.nix`

Ways to run these home-manager setups:

```sh
# via public github repo
nix run home-manager/master -- switch --flake github:jonknapp/dotfiles-v3 # infer user & hostname
nix run home-manager/master -- switch --flake github:jonknapp/dotfiles-v3#jon@megaman
nix run home-manager/master -- switch --flake github:jonknapp/dotfiles-v3#jon@zero

# via local code folder
nix run home-manager/master -- switch --flake . # infer user & hostname
nix run home-manager/master -- switch --flake .#jon@megaman
nix run home-manager/master -- switch --flake .#jon@zero
```

## Initial machine setup from Fedora Atomic

```sh
# step 1: provides nix
rpm-ostree rebase ostree-unverified-image:docker://ghcr.io/jonknapp/cosmic-atomic-nix:latest
systemctl reboot

# step 2: change to signed ostree containers
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/jonknapp/cosmic-atomic-nix:latest
systemctl reboot

# step 3: setup new machine and run initial home-manager setup
# ACTION: set the machine name to match a homeConfiguration (jon@<hostname>),
#         e.g. `hostnamectl set-hostname megaman`. When no `#output` is given,
#         home-manager (and the wrapper) picks `$USER@$(hostname)` from the flake.
nix run github:jonknapp/dotfiles-v3#setup-new-machine
nix run home-manager/master -- switch -b backup --flake github:jonknapp/dotfiles-v3
# ACTION: set up 1Password (installed by home-manager) so the SSH clone below works:
#         - log out and back in (or open a new login shell) so SSH_AUTH_SOCK points at
#           ~/.1password/agent.sock
#         - open 1Password and sign in
#         - Settings > Developer: enable "Use the SSH agent"
#         - verify with `ssh -T git@github.com`
#         - Settings > Developer: enable "Integrate with 1Password CLI"
# then re-run setup to configure vykar (skipped on the first run, before
# home-manager has installed it):
nix run github:jonknapp/dotfiles-v3#setup-new-machine

# step 4: pull down git repo and symlink for local home-manager use
mkdir -p ~/Projects && cd ~/Projects
git clone git@github.com:jonknapp/dotfiles-v3.git
ln -s ~/Projects/dotfiles-v3 ~/.config/home-manager
home-manager news # test setup works
```

## New machine script

`nix run .#setup-new-machine` performs one-time host setup:

- binary cache trust (below)
- on Linux, creates the `onepassword-cli` group and adds your user to it (via
  `sudo`), so the `op` wrapper from the 1Password module can use the desktop
  app integration. Not needed for the 1Password SSH agent.
- vykar: encrypts the repository passphrase (`op://cli/vykar/password`) as a
  systemd user credential (`$XDG_CONFIG_HOME/vykar/passphrase.cred`, default
  `~/.config`, bound to your user and this machine's host key / TPM; needs
  systemd >= 256) if a working one isn't there yet, and renders
  `$XDG_CONFIG_HOME/vykar/config.yaml` (mode 0600) from `config.yaml.template`
  with `op inject`. The template is the source of truth: if the existing config
  differs, it asks before overwriting it, keeps no backup (it would be another
  plaintext copy of the secrets) and shows no diff. It also offers to delete
  `config.yaml.bak-*` files left by older versions of the script. Skipped
  until home-manager has installed vykar, so re-run the script after the first
  `home-manager switch` and 1Password sign-in.

For the binary cache, it detects a multi-user (daemon) vs single-user Nix install
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

## Additional Information

- https://github.com/Doc-Steve/dendritic-design-with-flake-parts
- https://github.com/thrix/nix-toolbox
