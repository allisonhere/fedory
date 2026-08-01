# themes/

All 22 upstream themes are ported: `colors.toml` (palette data) plus every
per-theme override file upstream ships (`icons.theme`, `neovim.lua`,
`vscode.json`, `chromium.theme`, `hyprland.lua`, `btop.theme`,
`keyboard.rgb`, `shell.lock.toml` — whichever a given theme actually
defines; most rely on the generic templates in `default/themed/*.tpl`
instead). Fedory also ships the original `fedory-vesper` theme. See
[`docs/theming.md`](../docs/theming.md) for how the templating
engine turns `colors.toml` into every app's config, and
[`packaging/README.md`](../packaging/README.md)-style reasoning for why
`icons.theme` values (Yaru-*) need a COPR, same as upstream.

## Original wallpaper artwork

Upstream ships several hundred MB of wallpaper photography and composited
desktop screenshots. Those files are not copied here because some have
separate attribution or redistribution terms that should not be assumed to
follow the upstream code license.

Fedory instead ships nine pieces of original artwork under
`default/wallpapers/`. The upstream theme ports link their
`backgrounds/fedory.png` to the family that best matches each palette. Fedory
Vesper links four PNG scenes into its background directory. `fedory-theme-set`
dereferences those links while staging the active theme, keeping the runtime
state self-contained without storing duplicate images in Git.

The theme selector uses each linked wallpaper as its preview, and the
background selector exposes the active theme's artwork. User-specific images
can still be added under `~/.config/fedory/backgrounds/<theme-name>/`.
