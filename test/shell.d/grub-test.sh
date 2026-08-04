#!/bin/bash
# Covers bin/fedory-refresh-grub and the shipped GRUB theme.
#
# fedory-refresh-grub was a deliberate stub until now. The subtle part is not
# copying the theme -- it is that Fedora ships GRUB_TERMINAL_OUTPUT="console",
# which puts GRUB in text mode where themes are never rendered. A theme
# installed without flipping that key is completely invisible, so that
# assertion is the point of this file.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

work=$(mktemp -d)
fake_bin=$(mktemp -d)
cleanup() { rm -rf "$work" "$fake_bin"; }
trap cleanup EXIT

# Record invocations instead of touching this machine's boot configuration.
cat > "$fake_bin/grub2-mkconfig" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$work/mkconfig-calls"
out=""
while ((\$#)); do
  [[ \$1 == -o ]] && { out=\$2; shift 2; continue; }
  shift
done
[[ -n \$out ]] || exit 1
cat > "\$out" <<'CONFIG'
terminal_output gfxterm
loadfont (hd0,gpt2)/grub2/themes/fedory/fedory.pf2
insmod png
set theme=(hd0,gpt2)/grub2/themes/fedory/theme.txt
export theme
CONFIG
EOF
cat > "$fake_bin/grub2-mkfont" <<'EOF'
#!/bin/bash
# Mimic grub2-mkfont: -o <out> ... <input>
printf '%s\n' "$*" >> "${FEDORY_GRUB_MKFONT_CALLS:?}"
out=""
while (($#)); do
  [[ $1 == -o ]] && { out=$2; shift 2; continue; }
  shift
done
[[ -n $out ]] || exit 1
printf 'PFF2' > "$out"
EOF
# Manual refreshes elevate once through polkit. Pass the requested command
# straight through so the test covers that path without gaining privileges.
cat > "$fake_bin/pkexec" <<'EOF'
#!/bin/bash
exec "$@"
EOF
cat > "$fake_bin/grub2-script-check" <<'EOF'
#!/bin/bash
grep -q '^set theme=' "$1"
EOF
chmod +x "$fake_bin/grub2-mkconfig" "$fake_bin/grub2-mkfont" \
  "$fake_bin/grub2-script-check" "$fake_bin/pkexec"
export PATH="$fake_bin:$PATH"

export FEDORY_PATH="$ROOT_DIR"
export FEDORY_GRUB_THEME_DIR="$work/themes/fedory"
export FEDORY_GRUB_DEFAULTS="$work/default-grub"
export FEDORY_GRUB_CFG="$work/grub.cfg"
export FEDORY_GRUB_EFI_CFG="$work/no-such-efi-cfg"
export FEDORY_GRUB_MKFONT_CALLS="$work/mkfont-calls"

# Fedora's stock file, including the console setting that hides any theme.
cat > "$FEDORY_GRUB_DEFAULTS" <<'EOF'
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_TERMINAL_OUTPUT="console"
GRUB_GFXPAYLOAD_LINUX="keep"
GRUB_CMDLINE_LINUX="rhgb quiet"
GRUB_ENABLE_BLSCFG=true
EOF

output=$(bash "$ROOT_DIR/bin/fedory-refresh-grub" 2>&1)
status=$?
assert_eq 0 "$status" "refreshing the boot menu succeeds"

# --- the theme lands --------------------------------------------------------

assert_file_exists "$FEDORY_GRUB_THEME_DIR/theme.txt"
assert_file_exists "$FEDORY_GRUB_THEME_DIR/logo.png"
assert_file_exists "$FEDORY_GRUB_THEME_DIR/background.png"
if cmp -s "$ROOT_DIR/default/wallpapers/fedory-vesper-glasshouse.png" \
  "$FEDORY_GRUB_THEME_DIR/background.png"; then
  echo "ok: the Vesper Glasshouse background is installed"
else
  echo "FAIL: the installed GRUB background is not the Vesper Glasshouse artwork"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi
# 00_header only emits `loadfont` for .pf2 files inside the theme directory,
# so the generated font has to be there rather than in /boot/grub2/fonts.
assert_file_exists "$FEDORY_GRUB_THEME_DIR/fedory.pf2"
if grep -q -- '-s 32 -n Fedory' "$FEDORY_GRUB_MKFONT_CALLS"; then
  echo "ok: the generated boot menu font uses the readable 32px size"
else
  echo "FAIL: the generated boot menu font is not 32px"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

# --- the keys that make it visible -----------------------------------------

grub_value() { sed -n "s/^$1=//p" "$FEDORY_GRUB_DEFAULTS" | tr -d '"'; }

assert_eq "gfxterm" "$(grub_value GRUB_TERMINAL_OUTPUT)" \
  "the console setting that hides themes is replaced with gfxterm"
assert_eq "$FEDORY_GRUB_THEME_DIR/theme.txt" "$(grub_value GRUB_THEME)" \
  "the theme is selected"
assert_eq "1920x1080x32,1600x900x32,1280x720x32,1024x768x32,auto" \
  "$(grub_value GRUB_GFXMODE)" \
  "the theme prefers high-resolution widescreen modes with safe fallbacks"
assert_eq "text" "$(grub_value GRUB_GFXPAYLOAD_LINUX)" \
  "the themed menu hands Linux back to a reliable text payload"

# Replacing keys must not discard the distribution's own settings -- the kernel
# command line lives in this file.
assert_eq "rhgb quiet" "$(grub_value GRUB_CMDLINE_LINUX)" \
  "the existing kernel command line survives"
if grep -q '^GRUB_ENABLE_BLSCFG=true' "$FEDORY_GRUB_DEFAULTS"; then
  echo "ok: unrelated distribution keys are left alone"
else
  echo "FAIL: rewriting the defaults dropped unrelated keys"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

# A replaced key must not also be appended, or GRUB takes the last one and the
# file accumulates duplicates on every rerun.
assert_eq 1 "$(grep -c '^GRUB_TERMINAL_OUTPUT=' "$FEDORY_GRUB_DEFAULTS")" \
  "replacing a key does not leave a duplicate"

# --- regeneration -----------------------------------------------------------

assert_eq "-o $FEDORY_GRUB_CFG" "$(cat "$work/mkconfig-calls")" \
  "the boot menu is regenerated at the Fedora grub.cfg path"
if grep -q 'Verified the Fedory GRUB background and 32px font' <<<"$output"; then
  echo "ok: refresh verifies the deployed theme and generated configuration"
else
  echo "FAIL: refresh reports success without verifying the deployment"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

# --- idempotency ------------------------------------------------------------
#
# This is also the "reset my boot menu" command, so a second run must converge
# rather than accumulate.
bash "$ROOT_DIR/bin/fedory-refresh-grub" >/dev/null 2>&1
assert_eq 1 "$(grep -c '^GRUB_THEME=' "$FEDORY_GRUB_DEFAULTS")" \
  "rerunning does not duplicate keys"
assert_eq 2 "$(wc -l < "$work/mkconfig-calls")" \
  "rerunning regenerates the menu again"

# --- theme contents ---------------------------------------------------------

theme="$ROOT_DIR/default/grub/fedory/theme.txt"
font_name=$(sed -n 's/^terminal-font: *"\(.*\)"/\1/p' "$theme")
assert_eq "Fedory Regular 32" "$font_name" \
  "the theme names the font the installer generates"

# The theme avoids widget pixmap slices; a stray *_pixmap_style pointing at
# slices that are not shipped silently drops the widget it belongs to.
if grep -qE '_pixmap_style *= *"[^"]+"' "$theme"; then
  echo "FAIL: theme references pixmap slices that are not shipped"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: the theme draws with colours rather than unshipped pixmaps"
fi

# Every file the theme references has to ship with it.
while IFS= read -r asset; do
  if [[ -f "$ROOT_DIR/default/grub/fedory/$asset" ]]; then
    echo "ok: theme asset $asset ships"
  else
    echo "FAIL: theme references missing asset $asset"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
done < <(sed -n 's/.*file *= *"\([^"]*\)".*/\1/p' "$theme")

background=$(sed -n 's/^desktop-image: *"\([^"]*\)"/\1/p' "$theme")
assert_eq "background.png" "$background" \
  "the theme selects the installed Vesper background"

menu_block=$(sed -n '/^+ boot_menu {/,/^}/p' "$theme")
if grep -q '^[[:space:]]*left = 8%$' <<<"$menu_block" &&
  grep -q '^[[:space:]]*width = 84%$' <<<"$menu_block"; then
  echo "ok: the boot menu leaves enough width for Fedora BLS entry names"
else
  echo "FAIL: the boot menu is too narrow for Fedora BLS entry names"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

# --- wiring -----------------------------------------------------------------

if grep -q 'config/grub.sh' "$ROOT_DIR/install/config/all.sh"; then
  echo "ok: the boot menu step runs during install"
else
  echo "FAIL: install/config/all.sh never runs config/grub.sh"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

finish
