# packaging/package-map.tsv

The source of truth for how each package upstream Omarchy installs via
pacman/AUR is provided on Fedora. Seeded from upstream's
`install/omarchy-base.packages` and `install/omarchy-other.packages` (203
packages, full coverage — see `status` distribution below).

Tab-separated, one row per upstream package name:

| column | meaning |
| --- | --- |
| `upstream_pkg` | the exact pacman/AUR package name upstream installs |
| `fedora_pkg` | the dnf/rpm package name to install instead, or `-` |
| `copr` | a COPR repo (`owner/project`) to enable first, or `-` |
| `flatpak` | a Flatpak application ID, or `-` |
| `source_build` | how to build/install it from source when nothing else applies, or `-` |
| `status` | one of the values below — the primary resolution path |
| `rationale` | why, in enough detail to judge if it's still accurate later |

## `status` values

- `dnf` — direct `fedora_pkg` install, no complications.
- `dnf (RPM Fusion)` — direct install, but requires RPM Fusion (free and/or
  nonfree) enabled first.
- `dnf-or-copr` — try `fedora_pkg` via dnf first; fall back to the listed
  COPR on older Fedora releases where it isn't packaged yet.
- `copr` — not in Fedora's official repos; enable the listed COPR and
  install from there.
- `copr-or-source` — COPR is the preferred path but flaky/unmaintained
  enough that a source build is the documented fallback.
- `flatpak` — install the listed Flatpak app ID instead of a system package.
- `external-repo` — needs a vendor-provided dnf repo added (not a community
  COPR) — e.g. Docker CE's own repo, or the t2linux project's Fedora repo.
- `source-build` — no packaged path exists anywhere; build/install directly
  as described in `source_build`.
- `dropped` — no Fedora equivalent is installed, with `rationale` explaining
  why that's fine (Arch-only tooling with no functional gap on Fedora, a
  package Fedora already includes by default, etc).

`fedory-pkg-add` (`bin/fedory-pkg-add`) consults this file: pass it upstream
package names and it resolves dnf/COPR/Flatpak automatically. Rows marked
`dropped` are skipped with the rationale printed, not treated as an error.

## Known gaps to revisit

A handful of rows are marked `investigate` in `source_build` — these are
Basecamp's own first-party AUR-only tools (`aether`, `cliamp`, `omacut`,
`omawrite`, `tensaku`, `tobi-try`) where no independent upstream source repo
has been confirmed yet. Until that's resolved they're `dropped`. `usage` and
`mise` are the same family of tool (by the same upstream author, jdx) but
*do* have confirmed independent source, so they're `source-build` instead.

COPR repo names for the Hyprland ecosyston (`hyprland`, `hyprpicker`,
`hyprsunset`, `xdg-desktop-portal-hyprland`, `hyprland-guiutils`,
`hyprland-preview-share-picker`) and `quickshell-git` should be re-verified
at implementation time — Fedora's own Hyprland packaging status is moving
quickly, and `quickshell-git` in particular is load-bearing for the entire
Phase 6 shell.
