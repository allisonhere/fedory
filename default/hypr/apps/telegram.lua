-- Based on basecamp/omarchy default/hypr/apps/telegram.lua with Fedory command and path names.
-- Prevent Telegram from stealing focus on new messages.
o.window("org.telegram.desktop", { focus_on_activate = false })
