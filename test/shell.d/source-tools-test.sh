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
cat > "$fake_bin/fedory-pkg-add" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$fake_home/packages"
EOF
chmod +x "$fake_bin/xdg-settings" "$fake_bin/fedory-pkg-add"

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

  if rg -F 'mise use -g' "$wrapper" >/dev/null ||
    ! rg -F 'exec mise --quiet x' "$wrapper" >/dev/null; then
    echo "FAIL: source tool wrapper mutates mise config or leaks setup output: $command"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  else
    echo "ok: source tool wrapper uses quiet mise exec: $command"
  fi
done

cat >"$fake_bin/mise" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >"$fake_home/mise-args"
printf 'shell-init\n'
EOF
chmod +x "$fake_bin/mise"

assert_eq "shell-init" "$("$fake_home/.local/bin/starship" init bash)" \
  "starship wrapper returns only starship output"
assert_eq "--quiet x starship -- starship init bash" "$(<"$fake_home/mise-args")" \
  "starship wrapper invokes quiet mise exec"

cat >"$fake_home/.local/bin/starship" <<'EOF'
#!/bin/bash
mise use -g "starship" || exit 1
exec mise x "starship" -- "starship" "$@"
EOF
FEDORY_PATH="$ROOT_DIR" bash -euo pipefail "$ROOT_DIR/migrations/1785602840.sh" >/dev/null
if ! rg -F 'mise use -g' "$fake_home/.local/bin/starship" >/dev/null &&
  rg -F 'exec mise --quiet x' "$fake_home/.local/bin/starship" >/dev/null; then
  echo "ok: existing mise wrappers migrate to quiet execution"
else
  echo "FAIL: existing mise wrapper was not repaired"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

FEDORY_PATH="$ROOT_DIR" bash -euo pipefail "$ROOT_DIR/migrations/1785591485.sh" >/dev/null
FEDORY_PATH="$ROOT_DIR" bash -euo pipefail "$ROOT_DIR/migrations/1785591485.sh" >/dev/null
FEDORY_PATH="$ROOT_DIR" bash -euo pipefail "$ROOT_DIR/migrations/1785592782.sh" >/dev/null
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
assert_eq 1 "$(grep -c '^qrencode$' "$fake_home/packages")" \
  "the QR migration requests Fedora's native package"

if rg -q 'tensaku-edit|tui = "cliamp"|launch = "omawrite"' \
  "$ROOT_DIR/bin" "$ROOT_DIR/default" "$ROOT_DIR/config"; then
  echo "FAIL: runtime files still invoke an unavailable Basecamp tool"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: runtime files do not invoke unavailable Basecamp tools"
fi

finish
