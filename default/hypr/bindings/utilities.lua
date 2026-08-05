-- Based on basecamp/omarchy default/hypr/bindings/utilities.lua with Fedory command and path names.
o.bind("SUPER + SPACE", "Fedory menu", "fedory-menu toggle")
o.bind("SUPER + ALT + SPACE", "Apps menu", "fedory-menu toggle apps")
o.bind("SUPER + CTRL + E", "Emojis", "fedory-shell shell toggle fedory.emojis")
o.bind("SUPER + CTRL + C", "Capture menu", "fedory-menu toggle capture")
o.bind("SUPER + CTRL + O", "Toggle menu", "fedory-menu toggle toggle")
o.bind("SUPER + CTRL + H", "Hardware menu", "fedory-menu toggle hardware")
o.bind("SUPER + SHIFT + code:201", "Fedory menu", "fedory-menu toggle root")
o.bind("SUPER + ESCAPE", "System menu", "fedory-menu toggle system")
o.bind("XF86PowerOff", "Power menu", "fedory-menu toggle system", { locked = true })
o.bind("SUPER + K", "Show key bindings", "fedory-menu-keybindings")
o.bind("SUPER + ALT + K", "Show Tmux key bindings", "fedory-menu-tmux-keybindings")
o.bind("XF86Calculator", "Calculator", "fedory-calculator")
o.bind("SUPER + SHIFT + EQUAL", "Calculator", "fedory-calculator")

o.bind_toggle("SUPER + SHIFT + SPACE", "Toggle top bar", "bar")
o.bind("SUPER + CTRL + SPACE", "Background switcher", "fedory-menu toggle background")
o.bind("SUPER + SHIFT + CTRL + SPACE", "Theme menu", "fedory-menu toggle theme")
o.bind("SUPER + BACKSPACE", "Toggle window transparency", "fedory-hyprland-window-transparency-toggle")
o.bind("SUPER + SHIFT + BACKSPACE", "Toggle window gaps", "fedory-hyprland-window-gaps-toggle")
o.bind("SUPER + CTRL + BACKSPACE", "Toggle single-window square aspect", "fedory-hyprland-window-single-square-aspect-toggle")

-- xkbcommon names the comma keysym "comma"; the upper-case "COMMA" does not match.
o.bind("SUPER + comma", "Dismiss last notification", "fedory-shell notifications dismissOne")
o.bind("SUPER + SHIFT + comma", "Dismiss all notifications", "fedory-shell notifications dismissAll")
o.bind_toggle("SUPER + CTRL + comma", "Toggle silencing notifications", "notification-silencing")
o.bind("SUPER + ALT + comma", "Invoke last notification", "fedory-shell notifications invokeLast")
o.bind("SUPER + SHIFT + ALT + comma", "Open notification history", "fedory-shell notifications showHistory")

o.bind_toggle("SUPER + CTRL + I", "Toggle locking on idle", "idle")
o.bind_toggle("SUPER + CTRL + N", "Toggle nightlight", "nightlight")
o.bind("SUPER + CTRL + Delete", "Toggle laptop display", "fedory-hyprland-monitor-internal toggle")
o.bind("SUPER + CTRL + ALT + Delete", "Toggle laptop display mirroring", "fedory-hyprland-monitor-internal-mirror toggle")
o.bind("switch:on:Lid Switch", nil, "fedory-system-lid-close", { locked = true })
o.bind("switch:off:Lid Switch", nil, "fedory-hyprland-monitor-clamshell", { locked = true })

o.bind("PRINT", "Screenshot", "fedory-capture-screenshot")
o.bind("ALT + PRINT", "Screenrecording", "fedory-capture-screenrecording --stop-recording || fedory-menu toggle trigger.capture.screenrecord")
o.bind("SUPER + ALT + code:34", "Make webcam overlay smaller", "fedory-capture-webcam-resize smaller")
o.bind("SUPER + ALT + code:35", "Make webcam overlay larger", "fedory-capture-webcam-resize larger")
o.bind("SUPER + PRINT", "Color picker", "pkill hyprpicker || hyprpicker -a")
o.bind("SUPER + CTRL + PRINT", "Extract text (OCR) from screenshot", "fedory-capture-text")

-- While the slurp region picker is open, Return captures the entire focused
-- monitor. The bind lives exactly as long as a selection layer is on screen
-- (slurp opens one per monitor), so it cannot leak or get stuck.
local selection_layers = 0

hl.on("layer.opened", function(layer)
  if layer.namespace == "selection" then
    selection_layers = selection_layers + 1
    if selection_layers == 1 then
      hl.bind("RETURN", hl.dsp.exec_cmd("fedory-capture-region --take-fullscreen"), { description = "Capture entire screen" })
    end
  end
end)

hl.on("layer.closed", function(layer)
  if layer.namespace == "selection" and selection_layers > 0 then
    selection_layers = selection_layers - 1
    if selection_layers == 0 then
      hl.unbind("RETURN")
    end
  end
end)

o.bind("SUPER + CTRL + S", "Share", "fedory-menu toggle share")

o.bind("SUPER + CTRL + PERIOD", "Transcode", "fedory-transcode")

o.bind("SUPER + CTRL + R", "Set reminder", "fedory-menu toggle reminder-set")
o.bind("SUPER + CTRL + ALT + R", "Show reminders", "fedory-reminder show")
o.bind("SUPER + SHIFT + CTRL + R", "Clear reminders", "fedory-reminder clear")

o.bind("SUPER + CTRL + ALT + T", "Show time", "fedory-notification-time")
o.bind("SUPER + CTRL + ALT + B", "Show battery remaining", "fedory-notification-battery")
o.bind("SUPER + CTRL + ALT + W", "Toggle weather", "fedory-notification-weather")

o.bind("SUPER + SHIFT + CTRL + A", "Agent", "fedory-launch-agent")
o.bind("SUPER + CTRL + A", "Audio", "fedory-shell shell toggle fedory.audio")
o.bind("SUPER + CTRL + B", "Bluetooth", "fedory-shell shell toggle fedory.bluetooth")
o.bind("SUPER + CTRL + D", "Display", "fedory-shell shell toggle fedory.monitor")
o.bind("SUPER + CTRL + ALT + D", "Calendar", "fedory-shell shell toggle fedory.clock")
o.bind("SUPER + CTRL + W", "Network", "fedory-shell shell toggle fedory.network")
o.bind("SUPER + CTRL + P", "Power", "fedory-shell shell toggle fedory.power")
o.bind("SUPER + CTRL + T", "Activity", { tui = "btop" })

o.bind("SUPER + CTRL + Z", "Zoom in", function()
  local zoom = hl.get_config("cursor.zoom_factor") or 1
  hl.config({ cursor = { zoom_factor = zoom + 1 } })
end)

o.bind("SUPER + CTRL + ALT + Z", "Reset zoom", function()
  hl.config({ cursor = { zoom_factor = 1 } })
end)

o.bind("SUPER + CTRL + L", "Lock system", "fedory-system-lock")
