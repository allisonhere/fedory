# themes/

All 22 upstream themes are ported: `colors.toml` (palette data) plus every
per-theme override file upstream ships (`icons.theme`, `neovim.lua`,
`vscode.json`, `chromium.theme`, `hyprland.lua`, `btop.theme`,
`keyboard.rgb`, `shell.lock.toml` — whichever a given theme actually
defines; most rely on the generic templates in `default/themed/*.tpl`
instead). See [`docs/theming.md`](../docs/theming.md) for how the templating
engine turns `colors.toml` into every app's config, and
[`packaging/README.md`](../packaging/README.md)-style reasoning for why
`icons.theme` values (Yaru-*) need a COPR, same as upstream.

## What's deliberately not ported yet: wallpapers and preview screenshots

Upstream ships `backgrounds/*.{jpg,png}`, `preview.png`,
`preview-unlock.png`, and `unlock.png` per theme — several hundred MB of
binary image assets across all 22 themes. These were **not** copied into
this repo:

- Several are stock photography (filenames like `pawel-czerwinski.jpg`,
  `milad-fakurian.jpg` read as photographer credits), which may carry
  separate licensing/attribution terms from the repo's MIT code license —
  that needs verifying per-image before redistributing, not assuming.
  `theme-set` treats any image file in `themes/<name>/backgrounds/` as fair
  game to cycle through, so getting this wrong ships someone's copyrighted
  photo without permission.
  - `preview.png` / `preview-unlock.png` are large composited screenshots of
    the running desktop (bar, lock screen, etc. over a wallpaper) — same
    licensing question, plus they'd need to be recaptured against Fedory's
    own shell UI once Phase 6 exists anyway, so upstream's screenshots
    wouldn't even be accurate previews of this project.

**What still works without them:** `fedory-theme-set` degrades gracefully —
`choose_theme_background` simply finds zero backgrounds and
`fedory-notification-send`s "No background was found for theme" instead of
failing the whole theme switch (see `bin/fedory-theme-set`). Every color,
template, and app-specific override still applies correctly; only the
desktop wallpaper and README preview images are missing.

**To close this gap:** either (a) source a set of confirmed-openly-licensed
wallpapers per theme (Unsplash/Pexels images explicitly marked for reuse, or
originals) and drop them into `themes/<name>/backgrounds/`, or (b) reach out
about vendoring upstream's exact assets under their original license once
that's confirmed per-file. Either way, generate fresh `preview.png` shots
against Fedory's actual shell once Phase 6 lands — don't reuse upstream's.
