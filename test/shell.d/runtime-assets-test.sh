#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

required_assets=(
  default/bash/env-bootstrap
  default/fedory/fedory-menu.jsonc
  default/hypr/bootstrap.lua
  default/hypr/fedory.lua
  default/hypr/toggles.lua
  default/hypr/bindings/applications.lua
  default/hypr/bindings/utilities.lua
  default/hypr/apps/terminals.lua
  default/uwsm/env.d/10-fedory
  default/wayland-sessions/fedory.desktop
  default/xdg-terminal-exec/hyprland-xdg-terminals.list
  default/xcompose
)

for asset in "${required_assets[@]}"; do
  assert_file_exists "$ROOT_DIR/$asset"
done

if rg -F 'run_logged "$FEDORY_INSTALL/config/xdg-terminal-exec.sh"' \
  "$ROOT_DIR/install/config/all.sh" >/dev/null; then
  echo "ok: system setup installs xdg-terminal-exec"
else
  echo "FAIL: system setup skips xdg-terminal-exec"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

while IFS= read -r file; do
  if ! luac -p "$file"; then
    echo "FAIL: invalid Lua syntax: ${file#"$ROOT_DIR"/}"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
done < <(find "$ROOT_DIR/default/hypr" -type f -name '*.lua' | sort)
echo "ok: shipped Hyprland Lua modules parse"

missing_modules=()
while IFS= read -r module; do
  module_path=${module//./\/}.lua
  [[ -f $ROOT_DIR/$module_path ]] || missing_modules+=("$module")
done < <(
  rg -o 'require\("default\.hypr\.[^"]+' \
    "$ROOT_DIR/config/hypr" "$ROOT_DIR/default/hypr" \
    | sed 's/.*require("//' \
    | sort -u
)

if (( ${#missing_modules[@]} == 0 )); then
  echo "ok: every required default.hypr module is shipped"
else
  printf 'FAIL: missing Hyprland module: %s\n' "${missing_modules[@]}"
  ASSERT_FAILURES=$((ASSERT_FAILURES + ${#missing_modules[@]}))
fi

if rg -i 'omarchy' "$ROOT_DIR/default/hypr" \
  | rg -v 'Based on basecamp/omarchy' >/dev/null; then
  echo "FAIL: upstream Omarchy names remain in the Fedory Hyprland runtime"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: Hyprland runtime uses Fedory names"
fi

if rg 'uwsm-app' "$ROOT_DIR/bin" "$ROOT_DIR/default" "$ROOT_DIR/shell" \
  "$ROOT_DIR/config" >/dev/null; then
  echo "FAIL: runtime references the Arch-only uwsm-app wrapper"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: runtime uses Fedora's uwsm app command"
fi

for installed_path in \
  /etc/fedory.conf \
  /etc/profile.d/fedory.sh \
  /usr/share/uwsm/env.d/10-fedory \
  /usr/share/wayland-sessions/fedory.desktop; do
  if rg -F "$installed_path" "$ROOT_DIR/install/login/sddm.sh" >/dev/null; then
    echo "ok: login setup installs $installed_path"
  else
    echo "FAIL: login setup does not install $installed_path"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
done

if rg -F "Session=fedory.desktop" "$ROOT_DIR/install/login/sddm.sh" >/dev/null \
  && rg -F 'User=%s' "$ROOT_DIR/install/login/sddm.sh" >/dev/null; then
  echo "ok: login setup seeds the SDDM user and Fedory session"
else
  echo "FAIL: login setup does not seed complete SDDM state"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

if rg -F 'sddm.login(username.text' \
  "$ROOT_DIR/default/sddm/fedory/Main.qml" >/dev/null; then
  echo "ok: SDDM login uses the editable username"
else
  echo "FAIL: SDDM login still relies on an implicit last user"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

finish
