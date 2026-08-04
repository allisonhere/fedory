# Fedory migrations

Fedory migrations are one-time repair scripts for existing installs. They are
used when a package update needs to change state that dnf/rpm cannot safely own
by itself.

## Migration model

Migrations live in:

```text
migrations/*.sh
```

They run as the current Fedory user through `fedory-migrate`, normally during
`fedory update`. A migration may touch user/session state (`~/.config`,
`~/.local`, user systemd, browser/editor prefs, DBus/session state), and may also
perform machine-wide repairs when needed.

Completion state is per-user:

```text
~/.local/state/fedory/migrations/<migration filename>
```

That means every user gets a chance to run every migration. Migrations run as the
user; privileged operations should invoke the appropriate helper or privilege
prompt themselves. Migrations must be idempotent: if one user already applied a
machine-wide repair, the same migration running for another user should detect
that and no-op.

## When migrations run

### During `fedory update`

`fedory update` is the normal update path. It runs package updates, then:

```bash
fedory-migrate
fedory-hook post-update
```

`fedory-migrate` waits for any active dnf/rpm transaction to finish, then runs
all pending migrations for the current user in the visible update terminal.

### At login

Every graphical login starts `fedory-migrate-notify.service` after
`graphical-session.target`. The notifier checks:

```bash
fedory-migrate --pending
```

It stays silent while `fedory update` holds its lock, since that update applies
the pending migrations itself.

If that user has pending migrations, it shows a notification that opens a
terminal for:

```bash
fedory-migrate
```

The notifier never runs migrations silently in the background.

This is what covers users who did not run the update themselves: someone who
ran `sudo dnf update` directly instead of `fedory update` (upstream Omarchy
has an ALPM hook that redirects raw pacman calls back to `omarchy update`;
dnf has no direct equivalent hook mechanism, so Fedory has no such guard yet
-- see docs/scope.md), and any second user on the machine, whose migration
markers are per-user
and therefore still missing after another user updated.

Login is the only trigger on purpose. Watching the packaged migration directory
also fires during a normal `fedory update`, which prompts for migrations that
`fedory-migrate` is about to run in the visible update terminal.

### Manually

Users can safely run:

```bash
fedory-migrate
```

at any time. Already-completed migrations are skipped.

## Inspecting pending migrations

Use:

```bash
fedory-migrate --pending
```

Exit behavior:

- `0` — one or more migrations are pending
- non-zero — no migrations are pending

Output is one pending migration per line:

```text
1781158082.sh
```

## Creating a migration

Use the helper:

```bash
fedory-dev-add-migration --no-edit
```

This creates:

```text
migrations/<unix timestamp>.sh
```

New migration format:

- File permissions must be `0644` (`-rw-r--r--`). Migration runners execute them
  with `bash -euo pipefail`, not through executable bits.
- No shebang line.
- Start with an `echo` describing what the migration does.
- Use `$FEDORY_PATH` to reference the Fedory directory.
- Be idempotent. Check existing state before changing it.
- Use helper commands such as `fedory-cmd-present`, `fedory-cmd-missing`,
  `fedory-pkg-add`, `fedory-pkg-drop`, `fedory-pkg-present`, and
  `fedory-pkg-missing` when appropriate.
- Never restart the Fedory shell. `fedory update` restarts it unconditionally
  after migrations run, and the login-time shell already runs current code and
  hot-reloads `shell.json` edits.

Example:

```bash
echo "Relink Neovim theme to Fedory current state"

theme_link="$HOME/.config/nvim/lua/plugins/theme.lua"
current_relative_target="../../../../.local/state/fedory/current/theme/neovim.lua"

[[ -L $theme_link ]] || exit 0
ln -sfn "$current_relative_target" "$theme_link"
```

## Testing migrations

Run a migration against a temporary home when possible:

```bash
HOME=$(mktemp -d) bash -euo pipefail migrations/<timestamp>.sh
```

To rerun a migration locally, remove its marker and run the migrator:

```bash
rm ~/.local/state/fedory/migrations/<migration>.sh
fedory-migrate
```

Upstream Omarchy has a separate major-version upgrade command
(`omarchy-upgrade-to-quattro`) for jumping between incompatible installer
layouts, kept deliberately outside the normal migration runner. Fedory has
no equivalent yet since it has no version history of its own to migrate
across -- if that need arises later, keep following upstream's pattern of a
dedicated upgrade command rather than folding layout-jump work into regular
migrations.
