# Style

- Two spaces for indentation, no tabs
- Use bash 5 conditionals: use `[[ ]]` for string/file tests and `(( ))` for numeric tests
- In `[[ ]]`, don't quote variables, but do quote string literals when comparing values (e.g., `[[ $branch == "dev" ]]`)
- Prefer `(( ))` over numeric operators inside `[[ ]]` (e.g., `(( count < 50 ))`, not `[[ $count -lt 50 ]]`)
- For strings/paths with spaces, quote them instead of escaping spaces with `\ ` (e.g., `"$APP_DIR/Disk Usage.desktop"`, not `$APP_DIR/Disk\ Usage.desktop`)
- Shebangs must use `#!/bin/bash` consistently (never `#!/usr/bin/env bash`)
- Scripts under `install/` and `migrations/` may be sourced and intentionally omit shebangs

# Command Naming

All commands start with `fedory-`. Prefixes indicate purpose.

The authoritative command group list lives in `bin/fedory` in `GROUP_DESCRIPTIONS`. Keep `GROUP_DESCRIPTIONS` updated when adding a new command prefix.

Common prefixes include:

- `cmd-` - check if commands exist, misc utility commands
- `capture-` - screenshots, screen recordings, and other capture tools
- `pkg-` - package management helpers (dnf + COPR)
- `hw-` - hardware detection (return exit codes for use in conditionals)
- `refresh-` - copy default config to user's `~/.config/`
- `restart-` - restart a component
- `launch-` - open applications
- `install-` - install optional software
- `setup-` - interactive setup wizards
- `toggle-` - toggle features on/off
- `theme-` - theme management
- `update-` - update components

Do not maintain a second exhaustive prefix list here. Consult
`GROUP_DESCRIPTIONS` when selecting or checking a command group so this
guidance does not drift from the router.

# Command Metadata

Commands in `bin/` can declare CLI metadata in comments near the top of the file. `bin/fedory` scans the first 80 lines, and tests expect command metadata to remain valid.

Supported metadata keys:

- `# fedory:group=...` - override the command group inferred from the filename
- `# fedory:name=...` - override the command name inferred from the filename
- `# fedory:summary=...` - short help text
- `# fedory:args=...` - usage arguments
- `# fedory:examples=...` - examples separated with ` | `
- `# fedory:alias=...` / `# fedory:aliases=...` - alternate routes
- `# fedory:hidden=true` - hide from default command listings
- `# fedory:requires-sudo=true` - mark commands that require sudo

Only use `fedory:examples` where there are args that need explaining.

Prefer explicit metadata for user-facing commands. Keep routes consistent with the filename unless there is a deliberate alias or compatibility route.

Example:

```bash
# fedory:summary=Take a screenshot
# fedory:args=[smart|region|windows|fullscreen] [slurp|copy]
# fedory:examples=fedory screenshot | fedory capture screenshot region
```

# Runtime Environment

- `$FEDORY_PATH` is set at the top level by the uwsm session environment (or by `bootstrap.sh` / `bin/fedory` during install) and is always available to Fedory runtime code.
- Commands in `bin/` and Quickshell QML should rely on `$FEDORY_PATH` / `Quickshell.env("FEDORY_PATH")`; do not derive fallback paths from `HOME`, `Quickshell.shellDir`, or re-export/default `FEDORY_PATH` manually.

# Privileged Commands

- Whenever you need to trigger a privileged command, use `pkexec` so it results in a user prompt they can approve.
- Package operations go through `dnf`/`rpm`, run via `sudo` from an interactive terminal context (install/update flows), or `pkexec` from a GUI context. Never assume `pacman`, `yay`, or AUR — see `packaging/package-map.tsv` for the source of truth on how each upstream package is provided on Fedora.

# Git

- Commits should be atomic: include only one coherent change or fix, and do not mix unrelated work.
- Commit messages should be succinct and describe the change being made.

# Install Scripts

`bootstrap.sh` owns installation orchestration for an existing Fedora install (Fedory does not ship a custom ISO/ostree image; see `docs/scope.md`):

- `bin/fedory-setup-system` runs root-owned system setup.
- `bin/fedory-setup-hardware` runs idempotent hardware-specific setup and is called by `fedory-setup-system`.
- `bin/fedory-finalize-user` runs the per-user runtime finalization (skill symlinks, xdg-user-dirs, mime defaults, `install/user/all.sh`). Shipped user defaults are seeded from `default/` (our `/etc/skel`-style tree), not by this command. `bin/fedory-reinstall-configs` is the explicit destructive resync of those defaults into an existing user's `$HOME`.
- leaf scripts under `install/` are sourced by `run_logged $FEDORY_INSTALL/path/to/script.sh` and intentionally do not have shebangs.
- avoid `exit` in sourced setup scripts unless intentionally aborting setup.
- use `$FEDORY_INSTALL` and `$FEDORY_PATH` instead of hard-coded Fedory paths.
- keep root-scoped hardware setup under `install/hardware/` and orchestrate it through `install/hardware/all.sh`.
- keep every per-user setup leaf under `install/user/` (including `install/user/hardware/` and `install/user/first-run/`) so it is clear what must run for each user.
- prefer helper commands for package and command checks where available.

Raw `command -v`, `dnf`, and `rpm` are acceptable in package-helper contexts where direct package-manager behavior is the point of the script.

# Helper Commands

Use these instead of raw shell commands:

- `fedory-cmd-missing` / `fedory-cmd-present` - check for commands
- `fedory-pkg-missing` / `fedory-pkg-present` - check for packages (don't use these if you can just use `fedory-pkg-add`/`fedory-pkg-drop`)
- `fedory-pkg-add` - install packages (resolves dnf vs. COPR vs. Flatpak via `packaging/package-map.tsv`)
- `fedory-pkg-drop` - remove packages; use this instead of raw `dnf remove`
- `fedory-notification-send` - send desktop notifications; do not call `notify-send` directly
- `fedory-hw-asus-rog` - detect ASUS ROG hardware (and similar `hw-*` commands)

Commands installed by Fedory's default package set are runtime invariants. Invoke them directly; do not add defensive `fedory-cmd-present` / `fedory-cmd-missing` checks around them. Use command-presence helpers only for genuinely optional dependencies or code that can run before the default package set is installed.

Exceptions are allowed for migration and package-helper scripts where the helper may not be available yet, where the helper itself is being implemented, or where direct package-manager behavior is required.

# Config Structure

- `config/` - default configs copied to `~/.config/`
- `default/themed/*.tpl` - templates with `{{ variable }}` placeholders for theme colors
- `themes/*/colors.toml` - theme color definitions (accent, background, foreground, red/green/yellow/blue/magenta/cyan and bright_* variants)

# Tests

Run focused automated tests for the area you changed. Current test entry points:

- `./test/all` - aggregate runner for CLI and shell tests; it intentionally does not run graphical acceptance tests
- `./test/cli` - CLI routing, command metadata, theme helpers, and safe dispatch coverage
- `./test/shell` - all Fedory shell tests under `test/shell.d/`

New Fedory shell tests should live in `test/shell.d/*-test.sh` so `./test/shell` picks them up automatically. Source `test/shell.d/base-test.sh` for shared root-path discovery, assertions, and Node test helpers.

There is no build VM / disposable ISO harness for Fedory (see `docs/scope.md`), so graphical acceptance tests under `test/acceptance` are aspirational scaffolding: write them, but expect them to only actually run on a real Fedora+Hyprland+Quickshell machine, never in this sandbox.

# Visual Verification

Visual changes must be verified in the running UI in addition to automated
tests where a real desktop is available. This includes Fedory shell styling
and layout, panels, menus, notifications, desktop appearance, animations,
transitions, screenshots, and screen recording flows. Creating an artifact is
not sufficient: inspect it for clipping, overlap, incorrect spacing, stale
state, focus problems, and visual regressions before finishing.

Take a full-screen screenshot without opening the editor:

```bash
fedory capture screenshot fullscreen save
```

The command prints the saved path and writes to the configured Pictures
directory. Use `fedory screenshot` for the interactive smart-region flow.
Capture reference and candidate states as separate images when changing a
layer-shell surface or layout, then compare both.

When no graphical session is available (this is normally true in an agent
sandbox), state that plainly instead of claiming visual verification: rely on
`qmllint` (if present), manifest schema validation, and structural review
instead, and say so in the summary of the change.

# Fedory shell

The Quickshell desktop runs as a single long-running process out of
`shell/`. Hyprland autostart launches it directly with `quickshell -n -p`;
do not start additional standalone Quickshell instances for individual
components.

Run `fedory-restart-shell` after making changes to QML files.

Plugin contract:

- First-party plugins live directly under `shell/plugins/` or one category
  level deeper, such as `shell/plugins/panels/weather/`. First-party bar-only
  widgets may use adjacent `*.manifest.json` files. Third-party plugins live
  at `~/.config/fedory/plugins/<id>/` with a `manifest.json` at the root.
- Every plugin manifest declares `schemaVersion`, `id`, `name`, `version`,
  `kinds`, and `entryPoints`. See
  [`docs/fedory-shell.md`](docs/fedory-shell.md) and
  `shell/services/PluginRegistry.qml` for the current contract; fields such as
  `activation` are optional.
- Entry-point QML files are `Item`s (not `ShellRoot`), and accept the
  shell-injected properties `fedoryPath`, `shell`, `manifest`, and
  `pluginRegistry` / `barWidgetRegistry` as appropriate.
- Panel / overlay / menu plugins must expose `open(payloadJson)` and
  `close()` lifecycle methods for `shell summon` and `shell hide`.

IPC:

- `bin/fedory-shell` is the canonical IPC entry point. It forwards to
  the running shell and does not start it. Prefer it over re-implementing
  direct Quickshell socket calls in every CLI.
- The `shell` IPC target exposes lifecycle and configuration methods including
  `ping`, `summon`, `hide`, `toggle`, `call`, `rescanPlugins`, `reloadConfig`,
  `setPluginEnabled`, and `listPlugins`. Individual plugins can register
  additional IPC targets (the bar registers `bar`, the background switcher
  registers `image-selector`).

Widget files in `shell/plugins/bar/widgets/` contain Nerd Font glyphs as raw
unicode characters. The `Write` and `Edit` tools can strip multi-byte
codepoints in some positions — do **not** rewrite widget files wholesale
through those tools. For glyph fixes, use the targeted `Edit` tool with
the surrounding context, or a Python script that inserts codepoints via
`chr(0xXXXXX)`.

# Refresh Pattern

To copy a default config to user config with automatic backup:

```bash
fedory-refresh-config hypr/hyprlock.conf
```

This copies `$FEDORY_PATH/config/hypr/hyprlock.conf` to `~/.config/hypr/hyprlock.conf`.

# Migrations

Read `docs/migrations.md` before creating or changing migrations.

Migrations are per-user and run through `fedory-migrate` during `fedory update` or from the login-time migration notification. Put migrations directly under `migrations/<timestamp>.sh`. Pending state is per-user under `~/.local/state/fedory/migrations/`, so every user gets a chance to run every migration. Migrations run as the user; privileged work should invoke the appropriate helper or privilege prompt, and no-op when another user already applied it.

To create a new migration, run `fedory-dev-add-migration --no-edit`.

New migration format:
- File permissions must be `0644` (`-rw-r--r--`); migration runners execute them with `bash -euo pipefail`, not through executable bits
- No shebang line
- Start with an `echo` describing what the migration does
- Use `$FEDORY_PATH` to reference the fedory directory
- Prefer helper commands such as `fedory-cmd-present`, `fedory-cmd-missing`, `fedory-pkg-present`, and `fedory-pkg-missing`

Migrations may use raw `dnf`, `rpm`, `command -v`, or direct config edits when needed for one-off repair work.

# Provenance

Fedory is a Fedora-targeted port of [basecamp/omarchy](https://github.com/basecamp/omarchy). When porting a file, note the upstream path it's based on in a short comment or in the commit message, and record any deliberate behavioral deviation (not just the package-manager swap) — future contributors diffing against upstream need to know what's an intentional fork vs. a port that drifted by accident.

When handling an `[Upstream] Omarchy changes require review` issue, follow
[`docs/ai-upstream-review.md`](docs/ai-upstream-review.md) before changing the
reviewed checkpoint.
