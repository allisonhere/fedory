<p align="center">
  <img src="applications/icons/fedory-logo.svg" width="120" alt="Fedory logo" />
</p>

<h1 align="center">Fedory</h1>

<p align="center">
  A beautiful, modern & opinionated Hyprland desktop for <strong>Fedora</strong>.<br>
  A Fedora-flavored port of <a href="https://github.com/basecamp/omarchy">Omarchy</a>.
</p>

<p align="center">
  <code>curl -fsSL https://raw.githubusercontent.com/allisonhere/fedory/master/bootstrap.sh | bash</code>
</p>

---

Fedory turns a fresh Fedora Workstation install into a fully configured,
good-looking, keyboard-driven Hyprland desktop with one command. You don't
need to know Arch, Hyprland, or Wayland going in — Fedory picks sensible
defaults for everything and gets out of your way.

## What you get

- **Hyprland**, tiling and gorgeous out of the box, with sane keybindings you
  can actually remember
- A themeable desktop shell (bar, launcher, notifications, panels) with **22
  built-in themes** you can switch between live — see [Themes](#themes) below
- A curated terminal + editor + dev-tooling setup, so a fresh machine is a
  productive machine
- One CLI, `fedory`, for everything: `fedory theme set nord`,
  `fedory update`, `fedory screenshot` — run `fedory` with no arguments to
  browse everything it can do
- Automatic config migrations, so `fedory update` never leaves your desktop
  half-upgraded

## Installing

Fedory installs onto an **existing Fedora Workstation** system — it isn't a
custom ISO/spin (see [`docs/scope.md`](docs/scope.md) for why, and what that
tradeoff means). Boot a normal Fedora install, log in, then run:

```bash
curl -fsSL https://raw.githubusercontent.com/allisonhere/fedory/master/bootstrap.sh | bash
```

The installer explains each step as it runs and tells you how long to expect
it to take. If something fails partway through, it's safe to re-run — steps
that already finished are skipped.

## Themes

Every theme ships a full color palette plus a matching wallpaper. Switch any
time with:

```bash
fedory theme list
fedory theme set "Tokyo Night"
```

All 22 themes are ported and fully functional: Catppuccin (+ Latte),
Ethereal, Everforest, Flexoki Light, Gruvbox, Hackerman, Kanagawa, Last
Horizon, Lumon, Lupine, Matte Black, Miasma, Nord, Osaka Jade, Retro '82,
Ristretto, Rosé Pine, Solitude, Tokyo Night, Vantablack, and White.

Fedory ships five pieces of original wallpaper artwork shared across the 22
palettes. The Theme and Background entries in the desktop menu use those
assets for visual selection immediately after a clean installation.

## Documentation

- [`docs/file-layout.md`](docs/file-layout.md) — where everything lives, and how repository assets map onto your system
- [`docs/theming.md`](docs/theming.md) — how the theme + template system works
- [`docs/migrations.md`](docs/migrations.md) — how `fedory update` keeps your config current
- [`docs/upstream-sync.md`](docs/upstream-sync.md) — how Omarchy changes are detected, reviewed, and deliberately ported
- [`docs/scope.md`](docs/scope.md) — how Fedory's install model differs from upstream Omarchy's, and why

## Relationship to Omarchy

Fedory is an independent, unofficial port of [Omarchy](https://github.com/basecamp/omarchy)
by DHH/Basecamp, adapted for Fedora (`dnf`/COPR/Flatpak instead of
pacman/AUR). It is not affiliated with or endorsed by Basecamp, 37signals, or
DHH. See [`AGENTS.md`](AGENTS.md) for contribution style and the porting
convention we follow when bringing over an upstream file.

## License

MIT, see [`LICENSE`](LICENSE).
