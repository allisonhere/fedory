# Shared styled-output helpers for the install pipeline. Mirrors the color
# vocabulary bootstrap.sh's own local helpers already established (63=info,
# 196=error, 42=success), adding the one tier bootstrap.sh never needed:
# warnings (214, amber) -- for things like "this note is worth reading but
# isn't an error" (an RPM Fusion reminder) or "this specific thing was
# skipped, everything else still happened" (a COPR that couldn't be
# enabled). bootstrap.sh can't source this file itself -- it runs before
# $FEDORY_PATH exists -- so its own helpers stay inline, kept in sync with
# this palette by convention rather than shared code.
#
# Every function degrades to a plain, still-readable echo when gum isn't on
# PATH, the same defensive pattern bootstrap.sh uses.
#
# The `--` before "$*" in every gum call below is load-bearing, not
# decorative: gum's flag parser treats any argument starting with "-" as an
# unrecognized flag rather than text, so a message starting with "->" (used
# by run_logged's step announcements) silently printed gum's own usage/error
# instead of the message. `--` marks "everything after this is a positional
# argument," the standard fix, and protects against any future message that
# happens to start with a dash for any reason.

has_gum() { command -v gum >/dev/null 2>&1; }

ui_info() {
  if has_gum; then
    gum style --foreground 63 -- "$*"
  else
    echo "  $*"
  fi
}

ui_warn() {
  if has_gum; then
    gum style --foreground 214 --bold -- "Warning: $*" >&2
  else
    echo "Warning: $*" >&2
  fi
}

ui_error() {
  if has_gum; then
    gum style --foreground 196 --bold -- "Error: $*" >&2
  else
    echo "Error: $*" >&2
  fi
}

ui_success() {
  if has_gum; then
    gum style --foreground 42 --bold -- "$*"
  else
    echo "$*"
  fi
}

ui_task_success() {
  if has_gum; then
    gum style --foreground 42 --bold -- "  DONE  $*"
  else
    echo "  DONE  $*"
  fi
}

ui_task_failure() {
  if has_gum; then
    gum style --foreground 196 --bold -- "  FAIL  $*" >&2
  else
    echo "  FAIL  $*" >&2
  fi
}
