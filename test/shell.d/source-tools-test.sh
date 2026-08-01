#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

fake_home=$(mktemp -d)
fake_bin=$(mktemp -d)
browser_state="$fake_home/browser"
cleanup() { rm -rf "$fake_home" "$fake_bin"; }
trap cleanup EXIT

cat > "$fake_bin/xdg-settings" <<EOF
#!/bin/bash
if [[ \$1 == "get" ]]; then
  cat "$browser_state"
else
  printf '%s\n' "\$3" > "$browser_state"
fi
EOF
chmod +x "$fake_bin/xdg-settings"

export HOME="$fake_home"
export PATH="$fake_bin:$ROOT_DIR/bin:$PATH"

mkdir -p "$fake_home/.config/imv"
echo '<Ctrl+e> = exec tensaku-edit image.png' > "$fake_home/.config/imv/config"
echo chromium.desktop > "$browser_state"

bash "$ROOT_DIR/install/user/source-tools.sh"

for command in lazygit lazydocker starship dua tree-sitter usage uv tte tzupdate; do
  wrapper="$fake_home/.local/bin/$command"
  assert_file_exists "$wrapper"
  if [[ -x $wrapper ]]; then
    echo "ok: source tool wrapper is executable: $command"
  else
    echo "FAIL: source tool wrapper is not executable: $command"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
done

FEDORY_PATH="$ROOT_DIR" bash -euo pipefail "$ROOT_DIR/migrations/1785591485.sh" >/dev/null
FEDORY_PATH="$ROOT_DIR" bash -euo pipefail "$ROOT_DIR/migrations/1785591485.sh" >/dev/null
assert_file_exists "$fake_home/.config/starship.toml"
shell_integration_count=$(grep -c '^# Fedory shell integrations$' "$fake_home/.bashrc")
assert_eq 1 "$shell_integration_count" "the Bash integration is added idempotently"
if rg -q 'exec pinta' "$fake_home/.config/imv/config"; then
  echo "ok: existing IMV config migrates to Pinta"
else
  echo "FAIL: existing IMV config still invokes tensaku-edit"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi
assert_eq "org.chromium.Chromium.desktop" "$(<"$browser_state")" \
  "existing users migrate to Flatpak Chromium's desktop ID"

if rg -q 'tensaku-edit|tui = "cliamp"|launch = "omawrite"' \
  "$ROOT_DIR/bin" "$ROOT_DIR/default" "$ROOT_DIR/config"; then
  echo "FAIL: runtime files still invoke an unavailable Basecamp tool"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: runtime files do not invoke unavailable Basecamp tools"
fi

finish
