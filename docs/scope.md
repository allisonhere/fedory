# Scope: how Fedory differs from upstream Omarchy's install model

Omarchy 4.0 ("Quattro") split into four repos: `omarchy` (this repo's
upstream), `omarchy-settings` (pre-`useradd` `/etc/skel` seeding, built as an
Arch package), `omarchy-pkgs` (PKGBUILDs, including first-party AUR-only
tools), and `omarchy-iso` (a full custom archiso installer with its own
Anaconda-style orchestration and disposable-VM acceptance-test harness).

Fedory does **not** attempt a byte-for-byte port of that model. Building and
testing a custom Fedora spin (kickstart + `livemedia-creator` + a disposable
VM test harness) is a separate, much larger undertaking that this project
cannot exercise or verify in a sandboxed, headless environment.

Instead, Fedory ships as a **bootstrap layer on top of an existing, freshly
installed Fedora Workstation system** — the same shape Omarchy itself had for
most of its life, before the ISO split:

- `bootstrap.sh` is a curl-pipeable entry point (there is no upstream
  equivalent post-Quattro; this is Fedory-invented) that clones this repo to
  `~/.local/share/fedory/` and hands off to `bin/fedory-setup-system`.
- `config/` and `default/` play the role of `omarchy-settings`' `/etc/skel`
  seeding, except copied into an *existing* user's `$HOME` at
  bootstrap/finalize time instead of at `useradd -m` time:
  `install/user/config-seed.sh` seeds `~/.config` from `config/`
  (non-destructive), and `fedory-refresh-applications` seeds
  `~/.local/share/applications` from `default/applications` -- both run as
  part of `fedory-finalize-user`. `fedory-reinstall-configs` is the
  explicit, destructive "reset everything" path `/etc/skel` gives upstream
  for free on a fresh `useradd`.
- `packaging/package-map.tsv` plays the role of `omarchy-pkgs`: the source of
  truth for how each upstream Arch/AUR package maps onto Fedora (`dnf`, COPR,
  Flatpak, build-from-source, or "no equivalent, dropped").
- A Fedora kickstart/ISO path remains a documented stretch goal, not core
  work. If it's ever pursued, `omarchy-iso`'s `phases_impl.py` orchestrator is
  worth reading as prior art for how to structure the build/test phases.

This means a few upstream behaviors don't have a Fedory equivalent yet, and
should be called out explicitly wherever they come up rather than silently
dropped:

- Root-owned, pre-`useradd` system state (bootloader theme, Plymouth splash,
  fonts) that upstream seeds before the user account even exists. Fedory
  applies these to a running system instead.
- The pacman-transaction ALPM hook that redirects raw `pacman -Syu` to
  `omarchy update`. Fedory's equivalent (if built) would need a dnf plugin or
  a documented convention instead, since dnf has no direct hook analog.
- The disposable-VM graphical acceptance-test harness (`omarchy-iso-test`).
  Fedory's `test/acceptance` exists as scaffolding for a real Fedora+Hyprland
  machine, not as something runnable here.
- `omarchy-upgrade-to-quattro`: a self-contained migration for pre-Quattro
  Omarchy installs (Arch package-channel juggling: stable/rc/edge,
  `omarchy`/`omarchy-dev`, `omarchy-settings`). Fedory has no install
  lineage of its own to migrate from -- every shipped file already reflects
  the current correct state (same reasoning as the dropped historical
  migrations, see `migrations/README.md`) -- so there's nothing for a Fedory
  equivalent to upgrade *from*.
- `omarchy-upload-log`: uploads to `logs.omarchy.org`, a hosted paste
  service Fedory doesn't run. `fedory-debug` keeps the "view / save
  locally" options and drops the upload option rather than silently
  pointing at someone else's server.
- `omarchy-pkg-aur-accessible` / `-aur-add` / `-aur-install`: AUR-specific
  tooling superseded by `fedory-pkg-copr-add`. COPR's project-per-repo model
  (vs. AUR's single flat, fuzzy-searchable namespace) means the fuzzy-finder
  package browser (`-aur-install`) isn't a faithful port -- it would be a new
  feature built against COPR's search API, not a rename. Not built here.
