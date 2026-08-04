---
name: fedory
description: >
  REQUIRED for end-user customization of Linux desktop, window manager, or system config.
  Use when editing ~/.config/hypr/, ~/.config/fedory/,
  ~/.config/alacritty/, ~/.config/foot/, ~/.config/kitty/, or ~/.config/ghostty/.
  Triggers: Hyprland, window rules, animations, keybindings, monitors, gaps, borders,
  blur, opacity, fedory-shell, bar, terminal config, themes, background,
  night light, idle, lock screen, screenshots, reminders, layer rules, workspace
  settings, display config, and user-facing fedory commands. Excludes Fedory
  source development through `fedory dev link` workflows.
---

# Fedory Skill

Manage [Fedory](https://fedory.org/) Linux systems - a Fedora Workstation adaptation of Omarchy with Hyprland.

This skill is for end-user customization on installed systems.
It is not for contributing to Fedory source code.

## When This Skill MUST Be Used

**ALWAYS invoke this skill for end-user requests involving ANY of these:**

- Editing ANY file in `~/.config/hypr/` (window rules, animations, keybindings, monitors, etc.)
- Editing `~/.config/fedory/shell.json` (status bar layout, widgets)
- Editing terminal configs (alacritty, foot, kitty, ghostty)
- Editing ANY file in `~/.config/fedory/`
- Window behavior, animations, opacity, blur, gaps, borders
- Layer rules, workspace settings, display/monitor configuration
- Themes, backgrounds, fonts, appearance changes
- User-facing `fedory` commands (`fedory theme ...`, `fedory refresh ...`, `fedory restart ...`, etc.)
- Screenshots, screen recording, reminders, night light, idle behavior, lock screen

**If you're about to edit a config file in ~/.config/ on this system, STOP and use this skill first.**

**Do NOT use this skill for Fedory development tasks** (editing the Fedory source tree, creating migrations, or running `fedory dev ...` workflows).

## Critical Safety Rules

When invoking a privileged command directly, use `pkexec` instead of `sudo` so Fedory can show a graphical authorization prompt with command context. Do not wrap commands that already manage privilege elevation themselves.

**For end-user customization tasks, NEVER modify anything in `/usr/share/fedory/`** - but READING is safe and encouraged.

This directory contains Fedory's source files managed by git. Any changes will be:
- Lost on next `fedory update`
- Cause conflicts with upstream
- Break the system's update mechanism

```
/usr/share/fedory/     # READ-ONLY - NEVER EDIT (reading is OK)
├── bin/                    # Source scripts (symlinked to PATH)
├── config/                 # Default config templates
├── themes/                 # Stock themes
├── default/                # System defaults
├── shell/                  # Fedory shell source and defaults
├── migrations/             # Update migrations
└── install/                # Installation scripts
```

**Reading `/usr/share/fedory/` is SAFE and useful** - do it freely to:
- Understand how fedory commands work: `fedory theme set --help` or `cat $(which fedory-theme-set)`
- See default configs before customizing: `cat "$FEDORY_PATH/config/fedory/shell.json"`
- Check stock theme files to copy for customization
- Reference default hyprland settings: `cat /usr/share/fedory/default/hypr/*`

**Always use these safe locations instead:**
- `~/.config/` - User configuration (safe to edit)
- `~/.config/fedory/themes/<custom-name>/` - Custom themes (must be real directories)
- `~/.config/fedory/hooks/` - Custom automation hooks

If the request is to develop Fedory itself, this skill is out of scope. Follow repository development instructions instead of this skill.

## Privilege Escalation

For an interactive script or command run in a visible terminal, use `sudo` for
privileged work. Fedory may grant passwordless `sudo` access to particular
commands, and the terminal is the appropriate place to request a password
when one is needed.

Use `pkexec` only when the caller cannot interact with a terminal or cannot
enter a password there, such as a command launched by an agent or a graphical
background process. Do not replace `sudo` with `pkexec` merely because a
command changes system state.

## System Architecture

Fedory is built on:

| Component | Purpose | Config Location |
|-----------|---------|-----------------|
| **Fedora Linux** | Base OS | `/etc/`, `~/.config/` |
| **Hyprland** | Wayland compositor/WM | `~/.config/hypr/` |
| **Fedory shell** | Status bar + notifications (Quickshell) | `~/.config/fedory/shell.json` |
| **Launcher** | Quickshell launcher | `~/.config/fedory/shell.json` |
| **Alacritty/Foot/Kitty/Ghostty** | Terminals | `~/.config/<terminal>/` |
| **Fedory OSD** | On-screen display | Quickshell plugin |

## Command Discovery

Fedory ships a single `fedory` CLI that dispatches to all `fedory-*` binaries via `fedory <group> <action>`. Always prefer this form — it is self-documenting and stable. The underlying `fedory-*` binaries still exist on `PATH` and remain safe to read for source.

```bash
# List every documented command and its summary
fedory commands

# Show the commands inside a group
fedory theme --help
fedory refresh --help
fedory restart --help

# Show help for a specific command (does not execute it)
fedory theme set --help

# Machine-readable listing (binary, route, summary, args, aliases)
fedory commands --json

# Read a command's source to understand it
cat $(which fedory-theme-set)
```

### Command Groups

Run `fedory --help` for the full list. The most common groups:

| Group | Purpose | Example |
|-------|---------|---------|
| `fedory refresh` | Reset config to defaults (backs up first) | `fedory refresh shell` |
| `fedory restart` | Restart a service/app | `fedory restart shell` |
| `fedory toggle` | Toggle feature on/off | `fedory toggle nightlight` |
| `fedory theme` | Theme management | `fedory theme set <name>` |
| `fedory bar` | Bar layout and widgets | `fedory bar move fedory.clock --section right` |
| `fedory plugin` | Manage/clone shell plugins | `fedory plugin clone fedory.clock` |
| `fedory hook` | Install automation hooks | `fedory hook install theme-set <script>` |
| `fedory install` | Install optional software / packages | `fedory install docker dbs` |
| `fedory launch` | Launch apps | `fedory launch browser` |
| `fedory capture` | Screenshots and recordings | `fedory capture screenshot` |
| `fedory reminder` | Desktop notification reminders | `fedory reminder 15 "Pickup Jack"` |
| `fedory pkg` | Package management | `fedory pkg add <pkg>` |
| `fedory setup` | Interactive setup wizards | `fedory setup security fingerprint` |
| `fedory update` | System updates | `fedory update` |

## Configuration Locations

### Hyprland (Window Manager)

Fedory configures Hyprland in Lua. User files are loaded after Fedory's
defaults, so overrides go here:

```
~/.config/hypr/
├── hyprland.lua       # Main config (loads Fedory defaults, then user files)
├── bindings.lua       # Keybindings
├── monitors.lua       # Display configuration
├── input.lua          # Keyboard/mouse settings
├── looknfeel.lua      # Appearance (gaps, borders, animations)
├── autostart.lua      # Startup applications
└── hyprsunset.conf    # Night light / blue light filter
```

**Key behaviors:**
- Hyprland auto-reloads on config save (no restart needed for most changes)
- Use `hyprctl reload` to force reload
- After ANY Hyprland config change, validate with `hyprctl reload` followed by `hyprctl configerrors`
- If `hyprctl configerrors` reports errors, address them and rerun validation until clean or until a real blocker is identified
- Use `fedory refresh hyprland` to reset to defaults

### Fedory shell (Status Bar + Notifications)

The bar, notification daemon, settings panel, and assorted overlays all run
inside a single long-running Quickshell process (`fedory-shell`).

```
~/.config/fedory/shell.json             # User overrides: bar, plugins, idle
~/.config/fedory/plugins/<plugin-id>/   # User-owned shell plugins
$FEDORY_PATH/config/fedory/shell.json  # Canonical defaults
```

The shell hot-reloads `shell.json` on save — no restart needed for layout
changes. `idle.screensaver` and `idle.lock` are seconds since user idle began.

To customize a built-in bar widget, never edit `$FEDORY_PATH/shell/plugins/`.
Clone it into the user plugin directory instead:

```bash
fedory plugin clone fedory.workspaces
# Edit ~/.config/fedory/plugins/<username>.workspaces/; saved changes reload automatically.
```

**Commands:** `fedory restart shell`, `fedory refresh shell`

### Terminals

```
~/.config/alacritty/alacritty.toml
~/.config/foot/foot.ini
~/.config/kitty/kitty.conf
~/.config/ghostty/config
```

**Command:** `fedory restart terminal`

### Other Configs

| App | Location |
|-----|----------|
| btop | `~/.config/btop/btop.conf` |
| fastfetch | `/etc/fastfetch/config.jsonc` default; `~/.config/fastfetch/config.jsonc` user override |
| lazygit | `~/.config/lazygit/config.yml` |
| starship | `~/.config/starship.toml` |
| git | `~/.config/git/config` |

## Safe Customization Patterns

### Pattern 1: Edit User Config Directly

For simple changes, edit files in `~/.config/`:

```bash
# 1. Read current config
cat ~/.config/hypr/bindings.lua

# 2. Backup before changes
cp ~/.config/hypr/bindings.lua ~/.config/hypr/bindings.lua.bak.$(date +%s)

# 3. Make changes with Edit tool

# 4. Apply changes
# - Hyprland: auto-reloads on save, but MUST validate with `hyprctl reload` and `hyprctl configerrors`
# - Fedory shell: shell.json hot-reloads; use `fedory-shell shell rescanPlugins` for plugin/widget code changes
# - Launcher: restart with `fedory restart shell`
# - Terminals: MUST restart with `fedory restart terminal`
```

### Pattern 2: Make a new theme

1. Create a directory under ~/.config/fedory/themes.
2. See how an existing theme is done via /usr/share/fedory/themes/catppuccin.
3. Download a matching background (or several) from the internet and put them in ~/.config/fedory/themes/[name-of-new-theme]
4. When done with the theme, run `fedory theme set "Name of new theme"`

### Pattern 3: Use Hooks for Automation

Hooks live in `~/.config/fedory/hooks/<name>.d/` — one directory per event,
holding any number of independent scripts. Install with
`fedory hook install <name> <script>` (copies the script in and makes it
executable):

```
~/.config/fedory/hooks/
├── battery-low.d/          # Low battery (percentage in $1)
├── font-set.d/             # After font change (font name in $1)
├── post-boot.d/            # After the desktop starts
├── post-update.d/          # After `fedory update`
├── pre-refresh-dnf.d/   # Before package sync during update
└── theme-set.d/            # After theme change (theme slug in $1)
```

Example hook script:
```bash
#!/bin/bash
THEME_NAME=$1
echo "Theme changed to: $THEME_NAME"
# Add custom actions here
```

### Pattern 4: Reset to Defaults -- ALWAYS SEEK USER CONFIRMATION BEFORE RUNNING

When customizations go wrong:

```bash
# Reset specific config (creates backup automatically)
fedory refresh shell
fedory refresh hyprland

# The refresh command:
# 1. Backs up current config with timestamp
# 2. Copies default from $FEDORY_PATH/config/
# 3. Restarts the component
```

## Common Tasks

### Themes

```bash
fedory theme list              # Show available themes
fedory theme current           # Show current theme
fedory theme set <name>        # Apply theme ("Tokyo Night" and "tokyo-night" both work)
fedory theme bg next           # Cycle background
fedory theme install <url>     # Install from git repo
```

### Keybindings

Edit `~/.config/hypr/bindings.lua`. Format:
```lua
o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")
o.bind("SUPER + B", "Browser", { launch = "chromium" })  -- launch wraps with uwsm app
```

View current bindings: `fedory menu keybindings --print`

**IMPORTANT: When re-binding an existing key:**

1. First check existing bindings: `fedory menu keybindings --print`
2. If the key is already bound, you MUST call `hl.unbind(...)` BEFORE the new `o.bind(...)`
3. Inform the user what the key was previously bound to

Example - rebinding SUPER+F (which is bound to fullscreen by default):
```lua
-- Unbind existing SUPER+F (was: fullscreen)
hl.unbind("SUPER + F")
-- New binding for file manager
o.bind("SUPER + F", "File manager", { launch = "nautilus" })
```

Always tell the user: "Note: SUPER+F was previously bound to fullscreen. I've added an unbind to override it."

### Display/Monitors

Edit `~/.config/hypr/monitors.lua`. Format:
```lua
hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", position = "1920x0", scale = 1 })
```

List monitors and supported modes: `hyprctl monitors all`

### Window Rules

**CRITICAL: Hyprland window rules syntax changes frequently between versions.**

Before writing ANY window rules, you MUST fetch the current documentation from the official Hyprland wiki:
- https://wiki.hypr.land/Configuring/Window-Rules/

DO NOT rely on cached or memorized window rule syntax. The format has changed multiple times and using outdated syntax will cause errors or unexpected behavior.

Window rules go in `~/.config/hypr/hyprland.lua` or a required Lua module. Prefer Fedory's `o.window(match, rules)` helper — see examples in `$FEDORY_PATH/default/hypr/windows.lua`.

### Fonts

```bash
fedory font list               # Available fonts
fedory font current            # Current font
fedory font set <name>         # Change font
```

### System

```bash
fedory update                  # Full system update
fedory version                 # Show Fedory version
fedory debug --no-sudo --print # Debug info (ALWAYS use these flags)
fedory system lock             # Lock screen
fedory system shutdown         # Shutdown
fedory system reboot           # Reboot
```

**IMPORTANT:** Always run `fedory debug` with `--no-sudo --print` flags to avoid interactive sudo prompts that will hang the terminal.

## Troubleshooting

```bash
# Get debug information (ALWAYS use these flags to avoid interactive prompts)
fedory debug --no-sudo --print

# Reset specific config to defaults
fedory refresh <app>

# Refresh specific config file
# config-file path is relative to ~/.config/
# eg. `fedory refresh config hypr/hyprland.lua` will refresh ~/.config/hypr/hyprland.lua
fedory refresh config <config-file>

# Full reinstall of configs (nuclear option)
fedory reinstall
```

## Decision Framework

When user requests system changes:

1. **Is it a stock fedory command?** Use it directly
2. **Is it a config edit?** Edit in `~/.config/`, never `/usr/share/fedory/`
3. **Is it a theme customization?** Create a NEW custom theme directory
4. **Is it automation?** Use `fedory hook install` and the hook `.d` directories
5. **Is it a package install?** Use `fedory pkg add <pkgs...>` so Fedora, COPR, Flatpak, and source mappings are resolved consistently
6. **Is it built-in shell/plugin code?** Clone it with `fedory plugin clone`; never edit the packaged copy
7. **Unsure if command exists?** Run `fedory commands` (or `fedory <group> --help` for one group)

### Reminder Requests

When the user asks to set a reminder, use `fedory reminder <minutes> [message]` directly. Convert natural language durations to minutes and title-case short reminder labels when appropriate.

```bash
fedory reminder 15 "Pickup Jack"
fedory reminder 60 "Check laundry"
fedory reminder show
fedory reminder clear
```

## Out of Scope

This skill intentionally does not cover Fedory source development. Do not use this skill for:
- Editing files in `/usr/share/fedory/` (`bin/`, `config/`, `default/`, `shell/`, `themes/`, `migrations/`, etc.)
- Creating or editing migrations
- Running `fedory dev ...` commands

## Example Requests

- "Change my theme to catppuccin" -> `fedory theme set catppuccin`
- "Add a keybinding for Super+E to open file manager" -> Check existing bindings first, call `hl.unbind` if needed, then `o.bind` in `~/.config/hypr/bindings.lua`
- "Configure my external monitor" -> Edit `~/.config/hypr/monitors.lua`
- "Make the window gaps smaller" -> Edit `~/.config/hypr/looknfeel.lua`
- "Set up night light to turn on at sunset" -> `fedory toggle nightlight` or edit `~/.config/hypr/hyprsunset.conf`
- "Set a reminder to pickup jack in 15 minutes" -> `fedory reminder 15 "Pickup Jack"`
- "Show my reminders" -> `fedory reminder show`
- "Clear all reminders" -> `fedory reminder clear`
- "Customize the catppuccin theme colors" -> Create `~/.config/fedory/themes/catppuccin-custom/` by copying from stock, then edit
- "Run a script every time I change themes" -> Install it with `fedory hook install theme-set <script>`
- "Change how workspace labels are rendered" -> Clone `fedory.workspaces`, which switches the bar to `<username>.workspaces`, then edit the clone
- "Lock after ten minutes" -> Set `idle.lock` to `600` in `~/.config/fedory/shell.json`
- "Reset shell/bar to defaults" -> `fedory refresh shell`
