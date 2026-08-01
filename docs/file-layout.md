# File layout

Fedory installs onto an existing Fedora Workstation system. The repository is
the source of runtime commands and shipped defaults; it is not a filesystem
image, and there is intentionally no repository-level `etc/` mirror.

## Runtime and installation

- `bin/` contains the `fedory` command router and the `fedory-*` commands it
  dispatches. The checkout's `bin/` directory is added to `PATH`.
- `install/` contains the root and per-user setup phases. Leaf scripts are
  sourced by the setup orchestrators and may intentionally omit shebangs.
- `packaging/package-map.tsv` maps upstream package names to Fedora packages,
  COPR repositories, Flatpaks, source builds, or deliberate omissions.
- `migrations/` contains per-user migrations applied by `fedory-migrate`.
  Completion markers live under `~/.local/state/fedory/migrations/`.

## Shipped configuration and assets

- `config/` mirrors the initial `~/.config/` layout. First installation copies
  it non-destructively; `fedory-reinstall-configs` is the explicit destructive
  resync path for an existing user.
- `default/` holds assets consumed by specific installers and refresh commands,
  including theme templates, SDDM and Plymouth files, udev rules, and optional
  application launchers. It is not copied wholesale to one destination.
- `applications/` contains desktop launchers copied to
  `~/.local/share/applications/` and their shared artwork.
- `themes/` contains each theme's palette, shell tokens, and wallpaper assets.

System configuration is written by the scripts that own it. Depending on the
feature, destinations include `/etc`, `/usr/lib/systemd`, and other Fedora
system paths. Keeping those writes in their setup scripts makes privilege,
hardware detection, and Fedora-specific behavior explicit.

## Desktop shell

- `shell/` is the single long-running Quickshell desktop host.
- `shell/plugins/` contains built-in plugin manifests and entry points.
- `shell/services/` contains shared registries and services injected into
  plugins by the host.
- `config/fedory/shell.json` is the fresh-install shell configuration. Once a
  user customizes the shell, `~/.config/fedory/shell.json` is canonical.

## Supporting files

- `bootstrap.sh` is the curl-pipeable entry point for a fresh Fedora install.
- `test/` contains CLI and shell tests. Graphical acceptance scaffolding is
  separate because it requires a real Fedora, Hyprland, and Quickshell session.
- `AGENTS.md` documents contribution conventions and the Omarchy provenance
  requirements for ported files.
