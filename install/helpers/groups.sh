# Optional install groups.
#
# A fresh install is ~3.2 GiB, and some of that is software a given user may
# not want at all -- an office suite, video production tools, or the
# printing/mDNS daemons that also listen on the network. bootstrap.sh offers
# these as opt-out choices; every leaf that installs or enables something
# belonging to a group asks here first.
#
# Semantics are deliberately opt-out, and "unset" deliberately means "install
# everything": an upgrade path, an unattended run, or any caller that predates
# groups entirely must behave exactly as it did before. Only an explicit
# decision ever removes anything.
#
# FEDORY_DISABLED_GROUPS is a comma-separated list ("docker,printing"). When it
# is unset -- as opposed to set-but-empty, which means "nothing disabled" -- the
# machine's persisted choice is read instead, so a leaf run on its own outside
# a full bootstrap still sees what the user actually picked.

FEDORY_GROUPS_STATE_DEFAULT=/etc/fedory/disabled-groups

# fedory_disabled_groups -> prints the effective comma-separated list
fedory_disabled_groups() {
  if [[ -n ${FEDORY_DISABLED_GROUPS+x} ]]; then
    printf '%s' "$FEDORY_DISABLED_GROUPS"
    return 0
  fi

  local state="${FEDORY_GROUPS_STATE:-$FEDORY_GROUPS_STATE_DEFAULT}"
  [[ -f $state ]] || return 0
  # Tolerate a trailing newline and stray whitespace in the persisted file.
  tr -d '[:space:]' <"$state"
}

# fedory_group_enabled <name> -> 0 when the group should be installed
fedory_group_enabled() {
  local group="$1" disabled entry
  disabled=$(fedory_disabled_groups)

  [[ -n $disabled ]] || return 0

  local IFS=,
  for entry in $disabled; do
    [[ $entry == "$group" ]] && return 1
  done
  return 0
}

# fedory_group_packages <name> -> prints that group's package names, one per
# line, or nothing when the group is disabled or has no file. Mirrors the
# parse install/config/base-packages.sh already uses for the base list.
fedory_group_packages() {
  local group="$1"
  local file="${FEDORY_PATH:-}/install/groups/${group}.packages"

  fedory_group_enabled "$group" || return 0
  [[ -f $file ]] || return 0

  grep -v '^#' "$file" | grep -v '^$'
}
