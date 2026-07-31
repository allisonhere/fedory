# migrations/

This directory is intentionally empty of ported migrations. That's a
deliberate conclusion, not a skipped step -- here's the reasoning, so it
doesn't get second-guessed later without re-doing the work.

## Why none of upstream's 46 migrations were ported

A migration exists to repair **drift**: state that an *earlier* version of
the installer/config left behind, which needs correcting on machines that
already have that older state. Sampled across the full date range of
upstream's 46 migrations (earliest, middle, latest), every single one fits
that shape:

- `1778623107.sh` -- install a package Omarchy forgot to ship earlier
- `1780057136.sh` -- fix a terminal keybinding Omarchy previously shipped wrong
- `1780294774.sh` / `1784989000.sh` -- migrate `shell.json` from an older
  field format/layout to a newer one
- `1780517689.sh` -- add a browser extension flag Omarchy started shipping later
- `1780739888.sh` -- swap a default TUI tool Omarchy used to ship for a
  different one
- `1784510887.sh` -- rename a package Omarchy renamed upstream (beta -> stable)
- `1785351479.sh` -- remove a package that stopped being needed after an
  earlier Omarchy theme-integration change

None of these repair anything a **fresh** Fedory install can ever be in,
because Fedory has no install lineage of its own yet. Every file this port
ships under `install/`, `config/`, `default/`, and `bin/` already reflects
the *current, correct* end state directly -- there was never an earlier,
wrong Fedory state to have drifted from. Porting these migrations verbatim
would mean writing repair scripts for bugs that were introduced by (and
only ever existed in) Omarchy's own history, on a codebase that never had
those bugs.

## What *was* ported

The migration **mechanism** -- the part that's genuinely reusable
infrastructure, independent of any specific migration's content:

- `bin/fedory-migrate` -- the runner (per-user completion markers under
  `~/.local/state/fedory/migrations/`, `--pending` check, waits for an
  active dnf/rpm transaction before running -- see the file for why this
  needed a real rewrite, not just a rename, from upstream's pacman-lock
  wait)
- `bin/fedory-migrate-notify` -- the login-time notifier
- `bin/fedory-dev-add-migration` -- scaffolds a new `migrations/<unix
  timestamp>.sh` file
- `docs/migrations.md` -- the format/workflow documentation

## When to actually add one

Once Fedory has shipped a release and *its own* install/config templates
change in a way that needs repairing on already-bootstrapped machines --
not before. At that point, follow `docs/migrations.md` and use
`fedory-dev-add-migration --no-edit` the same way upstream does.
