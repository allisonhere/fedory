#!/bin/bash

# Enable AND start the user systemd units we ship. Runs at first-run rather
# than at finalize-user time because the user manager isn't fully live during
# bootstrap -- by first-run, the Hyprland/uwsm session is up and
# `systemctl --user enable --now` both writes the correct .wants symlinks
# (based on each unit's [Install]/WantedBy) and starts the services so the
# first session has bluetooth pairing, sleep lock, etc. live immediately
# instead of waiting for the next login. ConditionPath* in the unit files
# keep the enabled units inert on hardware they don't apply to.

#
# Most of these units are not ported yet -- only the tablet units exist under
# config/systemd/user. Enabling the whole list as one command therefore failed
# on every machine, and since fedory-first-run only marks itself complete when
# every step succeeds, that made first-run replay on each login and re-send its
# first-run toasts forever. Enable what is actually installed, say what is not,
# and fail only when a unit that does exist refuses to start.

set -uo pipefail

systemctl --user daemon-reload

units=(
  bt-agent.service
  fedory-recover-internal-monitor.service
  fedory-sleep-lock.service
  fedory-migrate-notify.service
  fedory-fcitx5.service
)

available=()
missing=()
for unit in "${units[@]}"; do
  if systemctl --user cat "$unit" >/dev/null 2>&1; then
    available+=("$unit")
  else
    missing+=("$unit")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "Not installed on this system, skipping: ${missing[*]}" >&2
fi

(( ${#available[@]} > 0 )) || exit 0

systemctl --user enable --now "${available[@]}"
