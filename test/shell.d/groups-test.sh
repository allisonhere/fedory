#!/bin/bash
# Covers install/helpers/groups.sh and the install/groups/*.packages lists.
#
# These groups let a user decline software at install time. The property that
# matters most is the boring one: with no choice recorded, every group is on,
# so upgrades, unattended runs, and any caller predating groups install exactly
# what they installed before.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

work_dir=$(mktemp -d)
cleanup() { rm -rf "$work_dir"; }
trap cleanup EXIT

export FEDORY_PATH="$ROOT_DIR"
export FEDORY_GROUPS_STATE="$work_dir/disabled-groups"
source "$ROOT_DIR/install/helpers/groups.sh"

# --- default posture -------------------------------------------------------

unset FEDORY_DISABLED_GROUPS
for group in office-media printing docker; do
  if fedory_group_enabled "$group"; then
    echo "ok: $group is enabled when nothing is recorded"
  else
    echo "FAIL: $group was disabled with no recorded choice"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
done

# Set-but-empty means "nothing declined", distinct from unset.
export FEDORY_DISABLED_GROUPS=""
if fedory_group_enabled docker; then
  echo "ok: an empty disabled list still enables every group"
else
  echo "FAIL: an empty disabled list disabled a group"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

# --- explicit declines -----------------------------------------------------

export FEDORY_DISABLED_GROUPS="docker"
if fedory_group_enabled docker; then
  echo "FAIL: docker stayed enabled after being declined"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: a declined group is disabled"
fi
if fedory_group_enabled printing; then
  echo "ok: declining one group leaves the others alone"
else
  echo "FAIL: declining docker also disabled printing"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

export FEDORY_DISABLED_GROUPS="docker,printing"
if fedory_group_enabled printing; then
  echo "FAIL: a comma-separated list did not disable the second entry"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: a comma-separated list disables every entry"
fi

# A prefix must not match: "print" is not "printing".
export FEDORY_DISABLED_GROUPS="print"
if fedory_group_enabled printing; then
  echo "ok: group names match exactly, not by prefix"
else
  echo "FAIL: a partial name disabled a group"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

# --- persisted fallback ----------------------------------------------------

unset FEDORY_DISABLED_GROUPS
printf 'office-media\n' >"$FEDORY_GROUPS_STATE"
if fedory_group_enabled office-media; then
  echo "FAIL: the persisted choice was ignored when the variable is unset"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: the persisted choice is read when the variable is unset"
fi

# An explicit variable wins over the file -- bootstrap's live choice must beat
# whatever a previous run recorded.
export FEDORY_DISABLED_GROUPS=""
if fedory_group_enabled office-media; then
  echo "ok: an explicit variable overrides the persisted file"
else
  echo "FAIL: the persisted file overrode an explicit choice"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi
rm -f "$FEDORY_GROUPS_STATE"

# --- package listing -------------------------------------------------------

unset FEDORY_DISABLED_GROUPS
mapfile -t office < <(fedory_group_packages office-media)
assert_eq 3 "${#office[@]}" "office-media lists its three packages"

export FEDORY_DISABLED_GROUPS="office-media"
mapfile -t office < <(fedory_group_packages office-media)
assert_eq 0 "${#office[@]}" "a declined group contributes no packages"
unset FEDORY_DISABLED_GROUPS

mapfile -t missing < <(fedory_group_packages does-not-exist)
assert_eq 0 "${#missing[@]}" "an unknown group is empty rather than an error"

# --- list hygiene ----------------------------------------------------------

# A package in both lists would be installed regardless of the user's choice,
# silently defeating the decline.
overlap=$(comm -12 \
  <(grep -hv '^#' "$ROOT_DIR"/install/groups/*.packages | grep -v '^$' | sort -u) \
  <(grep -v '^#' "$ROOT_DIR/install/fedory-base.packages" | grep -v '^$' | sort -u))
if [[ -z $overlap ]]; then
  echo "ok: no package is in both the base list and a group"
else
  echo "FAIL: packages appear in both the base list and a group: $overlap"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

# Every grouped name must resolve the same way base-list names do, or it would
# fail only for the users who kept the group. Mirrors package-map-test.sh.
unresolved=""
while IFS= read -r pkg; do
  [[ -n $pkg ]] || continue
  awk -F'\t' -v p="$pkg" 'NR>1 && $1==p { found=1 } END { exit !found }' \
    "$ROOT_DIR/packaging/package-map.tsv" || unresolved+="$pkg "
done < <(grep -hv '^#' "$ROOT_DIR"/install/groups/*.packages | grep -v '^$')
if [[ -z $unresolved ]]; then
  echo "ok: every grouped package resolves in package-map.tsv"
else
  echo "FAIL: grouped packages missing from package-map.tsv: $unresolved"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

finish
