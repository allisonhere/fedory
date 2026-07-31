#!/bin/bash
# Validates every shell/ plugin manifest against the contract documented in
# docs/fedory-shell.md and shell/services/PluginRegistry.qml: required
# fields present and correctly typed. This is the "independent of
# Quickshell being installed" check called for in the project plan --
# Quickshell itself can't run in this sandbox, so this is as close to
# compile-checking the plugin contract as we can get.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

REQUIRED_FIELDS=(schemaVersion id name version kinds entryPoints)
VALID_KINDS='["bar-widget","bar","panel","overlay","menu","service"]'

manifest_count=0
for manifest in $(find "$ROOT_DIR/shell" -name "manifest.json" -o -name "*.manifest.json"); do
  manifest_count=$((manifest_count + 1))
  rel="${manifest#"$ROOT_DIR"/}"

  if ! jq empty "$manifest" 2>/dev/null; then
    echo "FAIL: $rel is not valid JSON"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
    continue
  fi

  missing=()
  for field in "${REQUIRED_FIELDS[@]}"; do
    jq -e --arg f "$field" 'has($f)' "$manifest" >/dev/null 2>&1 || missing+=("$field")
  done

  if (( ${#missing[@]} > 0 )); then
    echo "FAIL: $rel missing required fields: ${missing[*]}"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
    continue
  fi

  if ! jq -e '.kinds | type == "array" and length > 0' "$manifest" >/dev/null 2>&1; then
    echo "FAIL: $rel: kinds must be a non-empty array"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
    continue
  fi

  unknown_kinds=$(jq -r --argjson valid "$VALID_KINDS" '.kinds - $valid | .[]' "$manifest" 2>/dev/null)
  if [[ -n $unknown_kinds ]]; then
    echo "FAIL: $rel: unrecognized kind(s): $unknown_kinds"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
    continue
  fi

  if ! jq -e '.entryPoints | type == "object" and (keys | length > 0)' "$manifest" >/dev/null 2>&1; then
    echo "FAIL: $rel: entryPoints must be a non-empty object"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
    continue
  fi

  # Every entry point QML file should actually exist next to the manifest.
  plugin_dir=$(dirname "$manifest")
  missing_entry=()
  while IFS= read -r entry; do
    [[ -f "$plugin_dir/$entry" ]] || missing_entry+=("$entry")
  done < <(jq -r '.entryPoints[]' "$manifest" 2>/dev/null)

  if (( ${#missing_entry[@]} > 0 )); then
    echo "FAIL: $rel: entry point file(s) not found: ${missing_entry[*]}"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
    continue
  fi

  echo "ok: $rel"
done

if (( manifest_count == 0 )); then
  echo "FAIL: no plugin manifests found under shell/"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

finish
