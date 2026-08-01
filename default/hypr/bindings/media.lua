-- Based on basecamp/omarchy default/hypr/bindings/media.lua with Fedory command and path names.
-- Volume, brightness, keyboard backlight, and touchpad controls.
o.bind("XF86AudioRaiseVolume", "Volume up", "fedory-audio-output-volume raise", { locked = true, repeating = true })
o.bind("XF86AudioLowerVolume", "Volume down", "fedory-audio-output-volume lower", { locked = true, repeating = true })
o.bind("XF86AudioMute", "Mute", "fedory-audio-output-volume mute-toggle", { locked = true })
o.bind("XF86AudioMicMute", "Mute microphone", "fedory-audio-input-mute", { locked = true })
o.bind("XF86MonBrightnessUp", "Brightness up", "fedory-brightness-display +5%", { locked = true, repeating = true })
o.bind("XF86MonBrightnessDown", "Brightness down", "fedory-brightness-display 5%-", { locked = true, repeating = true })
o.bind("SHIFT + XF86MonBrightnessUp", "Brightness maximum", "fedory-brightness-display 100%", { locked = true, repeating = true })
o.bind("SHIFT + XF86MonBrightnessDown", "Brightness minimum", "fedory-brightness-display 1%", { locked = true, repeating = true })
o.bind("XF86KbdBrightnessUp", "Keyboard brightness up", "fedory-brightness-keyboard up", { locked = true, repeating = true })
o.bind("XF86KbdBrightnessDown", "Keyboard brightness down", "fedory-brightness-keyboard down", { locked = true, repeating = true })
o.bind("XF86KbdLightOnOff", "Keyboard backlight cycle", "fedory-brightness-keyboard cycle", { locked = true })
o.bind_toggle("XF86TouchpadToggle", "Toggle touchpad", "touchpad", { locked = true })
o.bind("XF86TouchpadOn", "Enable touchpad", "fedory-toggle-touchpad on", { locked = true })
o.bind("XF86TouchpadOff", "Disable touchpad", "fedory-toggle-touchpad off", { locked = true })

-- Precise volume and brightness controls.
o.bind("ALT + XF86AudioRaiseVolume", "Volume up precise", "fedory-audio-output-volume +1", { locked = true, repeating = true })
o.bind("ALT + XF86AudioLowerVolume", "Volume down precise", "fedory-audio-output-volume -1", { locked = true, repeating = true })
o.bind("ALT + XF86MonBrightnessUp", "Brightness up precise", "fedory-brightness-display +1%", { locked = true, repeating = true })
o.bind("ALT + XF86MonBrightnessDown", "Brightness down precise", "fedory-brightness-display 1%-", { locked = true, repeating = true })

-- Media controls.
o.bind("XF86AudioNext", "Next track", "fedory-shell media next", { locked = true })
o.bind("ALT + XF86AudioPlay", "Next track", "fedory-shell media next", { locked = true })
o.bind("XF86AudioPause", "Pause", "fedory-shell media playPause", { locked = true })
o.bind("XF86AudioPlay", "Play", "fedory-shell media playPause", { locked = true })
o.bind("XF86AudioPrev", "Previous track", "fedory-shell media previous", { locked = true })
o.bind("ALT + SHIFT + XF86AudioPlay", "Previous track", "fedory-shell media previous", { locked = true })
o.bind("XF86Eject", "Eject media", "eject", { locked = true })

o.bind("SHIFT + XF86AudioMute", "Switch audio output", "fedory-audio-output-switch", { locked = true })
o.bind("SHIFT + XF86AudioPause", "Switch media source", "fedory-audio-source-switch", { locked = true })
o.bind("SHIFT + XF86AudioPlay", "Switch media source", "fedory-audio-source-switch", { locked = true })
