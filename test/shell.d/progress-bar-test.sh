#!/bin/bash
# Covers the block-drawing progress bars in install/helpers/logging.sh.
#
# installer-ui-test.sh pins itself to the ASCII fallback so its layout
# assertions stay locale-independent; this file is the one that actually
# exercises the Unicode rendering, the sub-cell precision, and the fallback
# boundary between them.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

source "$ROOT_DIR/install/helpers/logging.sh"

# Strip SGR sequences so assertions can talk about glyphs alone.
plain() { sed $'s/\033\\[[0-9;?]*[[:alpha:]]//g'; }

export LANG=en_US.UTF-8
unset LC_ALL LC_CTYPE
export FEDORY_PROGRESS_ASCII=0

# --- fallback boundary -----------------------------------------------------

if FEDORY_PROGRESS_ASCII=1 fedory_progress_unicode; then
  echo "FAIL: FEDORY_PROGRESS_ASCII=1 did not force the ASCII fallback"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: FEDORY_PROGRESS_ASCII=1 forces the ASCII fallback"
fi

if LANG=C LC_ALL=C fedory_progress_unicode; then
  echo "FAIL: a non-UTF-8 locale still selected block-drawing bars"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: a non-UTF-8 locale falls back to ASCII"
fi

assert_eq "####------" \
  "$(FEDORY_PROGRESS_ASCII=1 fedory_progress_bar 4 10 10 | plain)" \
  "the ASCII fallback still renders the original bar"

# --- determinate bar -------------------------------------------------------

empty=$(fedory_progress_bar 0 10 8 | plain)
assert_eq "░░░░░░░░" "$empty" "an empty bar is all track"

full=$(fedory_progress_bar 10 10 8 | plain)
assert_eq "████████" "$full" "a complete bar is all fill"

half=$(fedory_progress_bar 5 10 8 | plain)
assert_eq "████░░░░" "$half" "a half bar splits fill and track evenly"

# Sub-cell precision: 1/16th of an 8-cell bar is half a cell, which has to
# render as a partial block rather than rounding away to nothing. This is what
# keeps a slow step visibly moving instead of appearing stuck.
partial=$(fedory_progress_bar 1 16 8 | plain)
case "$partial" in
  '▌'*) echo "ok: fractional progress renders a partial block" ;;
  *) echo "FAIL: fractional progress did not render a partial block (got: $partial)"
     ASSERT_FAILURES=$((ASSERT_FAILURES + 1)) ;;
esac

# The gradient is the point -- a bar drawn in one flat colour is the boring
# case this replaced. Distinct colours must appear across a filled bar.
colours=$(fedory_progress_bar 10 10 24 | grep -o '38;5;[0-9]*' | sort -u | wc -l)
if (( colours >= 4 )); then
  echo "ok: a filled bar is drawn as a gradient ($colours colours)"
else
  echo "FAIL: filled bar used only $colours colour(s); expected a gradient"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

# --- activity (indeterminate) bar ------------------------------------------

sweep=$(fedory_activity_bar 0 16 | plain)
assert_eq 16 "${#sweep}" "the activity bar fills its full width"

# The comet's bright head must lead the direction of travel. At tick 0 the
# sweep is moving right, so the solid block sits at the right end of the
# segment with the fade behind it -- a symmetric blob would read as static.
case "$sweep" in
  *'▒▓█'*) echo "ok: the comet head leads while sweeping right" ;;
  *) echo "FAIL: no fading comet head while sweeping right (got: $sweep)"
     ASSERT_FAILURES=$((ASSERT_FAILURES + 1)) ;;
esac

# Once the sweep reverses, the head has to flip to the other end of the
# segment or the trail would run ahead of it.
reverse_tick=$(( 16 - 5 + 2 ))
reversed=$(fedory_activity_bar "$reverse_tick" 16 | plain)
case "$reversed" in
  *'█▓▒'*) echo "ok: the comet head flips when the sweep reverses" ;;
  *) echo "FAIL: comet head did not flip on reverse (got: $reversed)"
     ASSERT_FAILURES=$((ASSERT_FAILURES + 1)) ;;
esac

# The bar must actually move between ticks, in both renderings.
if [[ $(fedory_activity_bar 0 16 | plain) == $(fedory_activity_bar 3 16 | plain) ]]; then
  echo "FAIL: the activity bar did not advance between ticks"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: the activity bar advances between ticks"
fi

finish
