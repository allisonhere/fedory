#!/bin/bash
# Lints packaging/package-map.tsv: consistent columns, no duplicate
# upstream_pkg rows, and every row has a resolution appropriate to its
# status (see packaging/README.md for the status vocabulary).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

MAP="$ROOT_DIR/packaging/package-map.tsv"
assert_file_exists "$MAP"

col_count=$(awk -F'\t' 'NR==1{print NF}' "$MAP")
assert_eq 7 "$col_count" "package-map.tsv has 7 columns"

bad_columns=$(awk -F'\t' -v want="$col_count" 'NR>1 && NF!=want{print NR": "NF" columns"}' "$MAP")
if [[ -z $bad_columns ]]; then
  echo "ok: every row has $col_count columns"
else
  echo "FAIL: inconsistent column counts:"
  echo "$bad_columns"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

dupes=$(tail -n +2 "$MAP" | cut -f1 | sort | uniq -d)
if [[ -z $dupes ]]; then
  echo "ok: no duplicate upstream_pkg rows"
else
  echo "FAIL: duplicate upstream_pkg rows: $dupes"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

bad_status=$(tail -n +2 "$MAP" | awk -F'\t' '
  $6 !~ /^(dnf|dnf \(RPM Fusion\)|dnf-or-copr|copr|copr-or-source|flatpak|external-repo|source-build|dropped)$/ { print NR+1": "$1" -> "$6 }
')
if [[ -z $bad_status ]]; then
  echo "ok: every row has a recognized status value"
else
  echo "FAIL: unrecognized status values:"
  echo "$bad_status"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

# dnf/dnf-or-copr rows should name a fedora_pkg (col 2); flatpak rows should
# name a flatpak id (col 4); copr rows should name a copr repo (col 3).
incomplete=$(tail -n +2 "$MAP" | awk -F'\t' '
  ($6 == "dnf" || $6 == "dnf (RPM Fusion)" || $6 == "dnf-or-copr") && $2 == "-" { print NR+1": "$1" status="$6" has no fedora_pkg" }
  $6 == "flatpak" && $4 == "-" { print NR+1": "$1" status=flatpak has no flatpak id" }
  ($6 == "copr" || $6 == "copr-or-source") && $3 == "-" { print NR+1": "$1" status="$6" has no copr repo" }
')
if [[ -z $incomplete ]]; then
  echo "ok: every row's resolution matches its status"
else
  echo "FAIL: status/resolution mismatch:"
  echo "$incomplete"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

finish
