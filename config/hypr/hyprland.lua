-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Fedory's bootstrap keeps path setup out of this user config.
dofile((os.getenv("FEDORY_PATH") or "/usr/share/fedory") .. "/default/hypr/bootstrap.lua")

-- Disable all Fedory default bindings. Add your own in hypr/bindings.lua.
-- fedory_default_bindings = false
--
-- Or disable only bindings for Fedory's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- fedory_preinstalled_bindings = false

-- Load Fedory defaults.
require("default.hypr.fedory")

-- Put your personal overrides in these files. They're loaded after Fedory's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })
