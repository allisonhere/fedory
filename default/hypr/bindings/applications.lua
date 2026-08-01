-- Based on basecamp/omarchy default/hypr/bindings/applications.lua with Fedory command and path names.
-- Essential application bindings.
o.bind("SUPER + RETURN", "Terminal", { fedory = "terminal" })
o.bind("SUPER + SHIFT + RETURN", "Browser", { fedory = "browser" })
o.bind("SUPER + SHIFT + F", "File manager", { fedory = "nautilus" })
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { fedory = "nautilus-cwd" })
o.bind("SUPER + SHIFT + B", "Browser", { fedory = "browser" })
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", { fedory = "browser --private" })
o.bind("SUPER + SHIFT + N", "Editor", { fedory = "editor" })

if o.preinstalled_bindings_enabled() then
  -- Bindings for preinstalled Fedory applications, TUIs, and web apps.
  o.bind("SUPER + ALT + RETURN", "Tmux", { fedory = "terminal-tmux" })
  o.bind("SUPER + SHIFT + M", "Music", { fedory = "spotify" })
  o.bind("SUPER + SHIFT + D", "Docker", { tui = "lazydocker" })
  o.bind("SUPER + SHIFT + G", "Signal", { fedory = "signal" })
  o.bind("SUPER + SHIFT + O", "Obsidian", { fedory = "obsidian" })
  o.bind("SUPER + SHIFT + SLASH", "Passwords", { fedory = "1password" })

  -- Upstream's cliamp and omawrite bindings are intentionally omitted until
  -- those Basecamp tools have a confirmed source distribution for Fedora.

  o.bind("SUPER + SHIFT + A", "ChatGPT", { webapp = "https://chatgpt.com" })
  o.bind("SUPER + SHIFT + ALT + A", "Grok", { webapp = "https://grok.com" })
  o.bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://app.hey.com/calendar/weeks/" })
  o.bind("SUPER + SHIFT + E", "Email", { webapp = "https://app.hey.com" })
  o.bind("SUPER + SHIFT + ALT + E", "New email", { webapp = "https://app.hey.com/messages/new?display=standalone&new_window=true" })
  o.bind("SUPER + SHIFT + Y", "YouTube", { webapp = "https://youtube.com/" })
  o.bind("SUPER + SHIFT + ALT + G", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
  o.bind( "SUPER + SHIFT + CTRL + G", "Google Messages", { webapp = "https://messages.google.com/web/conversations", focus = true })
  o.bind("SUPER + SHIFT + P", "Google Photos", { webapp = "https://photos.google.com/", focus = true })
  o.bind("SUPER + SHIFT + S", "Google Maps", { webapp = "https://maps.google.com/", focus = true })
  o.bind("SUPER + SHIFT + X", "X", { webapp = "https://x.com/" })
  o.bind("SUPER + SHIFT + ALT + X", "X Post", { webapp = "https://x.com/compose/post" })
end
