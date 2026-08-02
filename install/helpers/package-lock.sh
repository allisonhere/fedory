# Guard against running a dnf transaction while another one already holds
# RPM's database lock.
#
# This lived in bin/fedory-migrate, where it only ever protected the migration
# runner. The install path needs it more: a fresh bootstrap runs while
# PackageKit/GNOME Software is doing its own boot-time refresh, and losing that
# race kills the entire base-package transaction. When that happened, dnf
# aborted with "Failed to obtain rpm transaction lock", 65 packages including
# sddm never installed, and the first visible symptom was install/login/sddm.sh
# failing to copy a theme into a /usr/share/sddm that did not exist.
#
# Fedora-native rewrite of upstream's wait_for_pacman_transaction: dnf/rpm
# don't have a single well-known lock *file* the way pacman's db.lck is --
# rpm's own db lock is held via flock on /var/lib/rpm/.rpm.lock for the
# duration of a transaction, not left behind as a stale marker, so `fuser`
# (which reports a lock as held only while a process actually has the fd
# open) is the accurate check here, with a pgrep fallback in case fuser
# isn't installed.
#
# wait_for_package_transaction [label] [timeout_seconds]
#   Returns 0 once no transaction is active, 1 if it gave up waiting.
#   Callers decide what a timeout means -- migrations defer to the next login,
#   the installer warns and presses on.
wait_for_package_transaction() {
  local label="${1:-Fedory setup}"
  local timeout="${2:-900}"
  # FEDORY_RPM_LOCK exists so the test suite can exercise the fuser branch on a
  # host that has no /var/lib/rpm. Production never sets it.
  local rpm_lock="${FEDORY_RPM_LOCK:-/var/lib/rpm/.rpm.lock}"

  transaction_active() {
    if command -v fuser >/dev/null 2>&1 && [[ -e $rpm_lock ]]; then
      fuser "$rpm_lock" >/dev/null 2>&1 && return 0
    fi
    # packagekitd remains alive while idle, so its process alone does not
    # indicate a package transaction. An active PackageKit transaction still
    # holds RPM's database lock and is detected by fuser above.
    pgrep -x 'dnf|dnf-3|dnf5|rpm' >/dev/null 2>&1
  }

  transaction_active || return 0
  echo "Waiting for a dnf/rpm transaction to finish before continuing $label..."

  local _
  for _ in $(seq 1 "$timeout"); do
    transaction_active || return 0
    sleep 1
  done

  return 1
}
