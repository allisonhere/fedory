# Native messaging host manifests

`allowed_origins` in these manifests still points at *Omarchy's* published
Chrome Web Store extension IDs (`bgpiichlckmfanooecilcjemknkcpngb` for Copy
URL, `dedjgknigfeelejglamclffonmophnfl` for yt-dlp) -- Fedory has not
published its own forks of those extensions, so as shipped these native
messaging hosts won't actually be reachable from a browser extension until
either Fedory publishes its own extensions (and these IDs are updated to
match) or a documented process for using Omarchy's originals is worked out.
The host binaries themselves (`fedory-chromium-copy-url-host`,
`fedory-chromium-ytdlp-host`) are fully ported and functional; this is
purely a "which extension is allowed to talk to it" gap.
