https://github.com/Doc-Steve/dendritic-design-with-flake-parts

```sh
home-manager build --flake .#jon@zero
```

- If you add new files, make sure to `git add` them so they are included as modules.
- If you adjust any flake inputs, make sure to run `nix run .#write-flake` to rebuild `flake.nix`
