-- Based on basecamp/omarchy default/hypr/apps/omarchy-shell.lua with Fedory command and path names.
-- Window and layer rules for the Fedory Quickshell surfaces. The
-- shell-wide bar / menu / popouts are layer-shell.

-- Keep the bar instant: no layer-shell fade/slide animation.
hl.layer_rule({ match = { namespace = "fedory-bar" }, no_anim = true, animation = "none" })

-- Launcher, image selector, emojis, clipboard overlays, and keyboard-driven
-- panels should pop without compositor layer fades. Panels keep their own
-- QML opacity transition for normal open/close, and skip it for panel handoff.
hl.layer_rule({ match = { namespace = "^(fedory-menu|fedory-image-selector|fedory-emojis|fedory-clipboard|fedory-keyboard-panel)$" }, no_anim = true, animation = "none" })

-- Dev gallery is the main shell workbench; open it maximized like
-- SUPER+ALT+F so component previews have the whole workspace.
o.window({ class = "^org.quickshell$", title = "^Fedory shell – dev gallery$" }, { maximize = true })
