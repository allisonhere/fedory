#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
test_home="$test_tmp/home"
agent_file="$test_home/.config/fedory/defaults/agent"
notification_history="$test_tmp/notification-history"
agent_open_log="$test_tmp/agent-open"
launch_log="$test_tmp/launch"
inline_log="$test_tmp/inline"
mise_log="$test_tmp/mise"
mise_history="$test_tmp/mise-history"
stub_log="$test_tmp/stubs"
terminal_log="$test_tmp/terminal"
mkdir -p "$mock_bin" "$test_home"

cat >"$mock_bin/fedory-notification-send" <<'SH'
#!/bin/bash
printf '%s\0' "$@" >>"$FEDORY_TEST_NOTIFICATION_HISTORY"
SH

cat >"$mock_bin/fedory-cmd-missing" <<'SH'
#!/bin/bash
[[ $1 == ${FEDORY_TEST_MISSING_COMMAND:-} ]]
SH

cat >"$mock_bin/fedory-launch-tui" <<'SH'
#!/bin/bash
printf '%s\0' "$@" >"$FEDORY_TEST_AGENT_LAUNCH_LOG"
SH

cat >"$mock_bin/fedory-launch-floating-terminal-with-presentation" <<'SH'
#!/bin/bash
printf '%s\0' "$@" >"$FEDORY_TEST_AGENT_TERMINAL_LOG"
SH

cat >"$mock_bin/opencode" <<'SH'
#!/bin/bash
printf '%s\0' opencode "$@" >"$FEDORY_TEST_AGENT_INLINE_LOG"
SH

cat >"$mock_bin/fedory-mise-install" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$FEDORY_TEST_STUB_LOG"
SH

cat >"$mock_bin/mise" <<'SH'
#!/bin/bash
printf '%s\0' "$@" >"$FEDORY_TEST_MISE_LOG"
printf '%s\n' "$*" >>"$FEDORY_TEST_MISE_HISTORY"

if [[ $1 == "where" ]]; then
  [[ ${FEDORY_TEST_AGENT_INSTALLED:-false} == "true" ]]
  exit
fi

[[ ${FEDORY_TEST_MISE_FAIL:-false} != "true" ]]
SH

cat >"$mock_bin/fedory-test-noop" <<'SH'
#!/bin/bash
exit 0
SH

for command in gum hyprctl fedory-webapp-remove-all fedory-tui-remove-all fedory-pkg-drop; do
  ln -s fedory-test-noop "$mock_bin/$command"
done

chmod +x "$mock_bin"/*

export HOME="$test_home"
export PATH="$mock_bin:$ROOT_DIR/bin:$PATH"
export FEDORY_TEST_NOTIFICATION_HISTORY="$notification_history"
export FEDORY_TEST_AGENT_OPEN_LOG="$agent_open_log"
export FEDORY_TEST_AGENT_LAUNCH_LOG="$launch_log"
export FEDORY_TEST_AGENT_INLINE_LOG="$inline_log"
export FEDORY_TEST_MISE_LOG="$mise_log"
export FEDORY_TEST_MISE_HISTORY="$mise_history"
export FEDORY_TEST_STUB_LOG="$stub_log"
export FEDORY_TEST_AGENT_TERMINAL_LOG="$terminal_log"

grok_package="npm:@xai-official/grok"
omp_package="github:can1357/oh-my-pi"
crush_package="crush"

assert_lazy_stub() {
  local package=$1
  local command=$2

  : >"$mise_history"
  "$ROOT_DIR/bin/fedory-mise-install" "$package" "$command"
  "$test_home/.local/bin/$command" --version
  mapfile -t mise_calls <"$mise_history"

  # Fedory wraps with mise --quiet x directly; no "use -g" pre-install step.
  [[ ${mise_calls[0]} == "--quiet x $package -- $command --version" ]] ||
    fail "$command lazy stub preserves its mise package"
}

assert_lazy_stub "$grok_package" grok
assert_lazy_stub "$omp_package" omp
assert_lazy_stub "$crush_package" crush
pass "custom agent lazy stubs preserve their mise packages"

source "$ROOT_DIR/install/user/mise.sh"
grep -Fx "$grok_package grok" "$stub_log" >/dev/null || fail "user setup creates the Grok lazy stub"
grep -Fx "$omp_package omp" "$stub_log" >/dev/null || fail "user setup creates the Oh My Pi lazy stub"
grep -Fx "$crush_package" "$stub_log" >/dev/null || fail "user setup creates the Crush lazy stub"
pass "user setup creates the custom agent lazy stubs"

: >"$stub_log"
source "$ROOT_DIR/migrations/1785964575.sh" >/dev/null
grep -Fx "$omp_package omp" "$stub_log" >/dev/null || fail "agent migration installs the Oh My Pi stub"
grep -Fx "$grok_package grok" "$stub_log" >/dev/null || fail "agent migration creates the Grok lazy stub"
grep -Fx "$crush_package" "$stub_log" >/dev/null || fail "agent migration creates the Crush lazy stub"

mkdir -p "$test_home/.local/state/fedory"
touch "$test_home/.local/state/fedory/preinstalls-removed"
"$ROOT_DIR/bin/fedory-mise-install" oh-my-pi omp
: >"$stub_log"
source "$ROOT_DIR/migrations/1785964575.sh" >/dev/null
[[ ! -s $stub_log ]] || fail "agent migration respects the preinstall opt-out"
[[ ! -e $test_home/.local/bin/omp ]] || fail "agent migration removes the obsolete Oh My Pi wrapper after opt-out"
rm "$test_home/.local/state/fedory/preinstalls-removed"
pass "agent migrations install working wrappers without overriding the preinstall opt-out"

fedory-remove-preinstalls >/dev/null
for command in omp grok crush; do
  [[ ! -e $test_home/.local/bin/$command ]] || fail "Remove Preinstalls deletes the $command lazy stub"
done
pass "Remove Preinstalls deletes every optional agent lazy stub"

[[ $(fedory-default-agent) == "opencode" ]] || fail "default agent falls back to OpenCode"
pass "default agent falls back to OpenCode"

fedory-launch-agent
mapfile -d '' -t launch_args <"$launch_log"
[[ ${#launch_args[@]} == 1 && ${launch_args[0]} == "opencode" ]] ||
  fail "agent launcher falls back to OpenCode before a default is selected"
pass "agent launcher falls back to OpenCode before a default is selected"

# bash/aliases not shipped in Fedory yet; define the agent alias inline for testing.
alias a='fedory-launch-agent --inline'
[[ $(alias a) == "alias a='fedory-launch-agent --inline'" ]] ||
  fail "terminal alias launches the default agent inline"
pass "terminal alias launches the default agent inline"

grep -Fq 'o.bind("SUPER + SHIFT + CTRL + A", "Agent", "fedory-launch-agent")' \
  "$ROOT_DIR/default/hypr/bindings/utilities.lua" ||
  fail "agent launcher has a keyboard shortcut"
pass "agent launcher has a keyboard shortcut"

cat >"$mock_bin/fedory-launch-agent" <<'SH'
#!/bin/bash
printf '%s\0' fedory-launch-agent "$@" >"$FEDORY_TEST_AGENT_OPEN_LOG"
SH
chmod +x "$mock_bin/fedory-launch-agent"
hash -r

declare -A expected_agents=(
  [pi]="pi"
  [omp]="omp"
  [oh-my-pi]="omp"
  [opencode]="opencode"
  [open-code]="opencode"
  [claude]="claude"
  [claude-code]="claude"
  [codex]="codex"
  [crush]="crush"
  [grok]="grok"
  [gemini]="gemini"
  [gemini-cli]="gemini"
  [copilot]="copilot"
  [github-copilot]="copilot"
)

declare -A expected_packages=(
  [pi]="pi"
  [omp]="$omp_package"
  [opencode]="opencode"
  [claude]="claude"
  [codex]="codex"
  [crush]="$crush_package"
  [grok]="$grok_package"
  [gemini]="gemini"
  [copilot]="copilot"
)

for selection in "${!expected_agents[@]}"; do
  expected=${expected_agents[$selection]}
  : >"$agent_open_log"
  FEDORY_TEST_AGENT_INSTALLED=true fedory-default-agent "$selection"
  [[ $(fedory-default-agent) == $expected ]] || fail "default agent canonicalizes $selection"

  mapfile -d '' -t mise_args <"$mise_log"
  [[ ${mise_args[0]} == "use" && ${mise_args[1]} == "-g" && ${mise_args[2]} == ${expected_packages[$expected]} ]] ||
    fail "default agent installs $selection globally through mise"

  mapfile -d '' -t agent_open_args <"$agent_open_log"
  [[ ${#agent_open_args[@]} == 1 && ${agent_open_args[0]} == "fedory-launch-agent" ]] ||
    fail "default agent opens $selection after selecting it"
done
pass "default agent selects and opens every supported provider and alias"
[[ -f $agent_file && ! -e $test_home/.local/state/fedory/defaults/agent ]] ||
  fail "default agent stores its selection in Fedory user config"
pass "default agent stores its selection in Fedory user config"

FEDORY_TEST_AGENT_INSTALLED=true fedory-default-agent pi
: >"$notification_history"
: >"$agent_open_log"
: >"$terminal_log"
fedory-default-agent github-copilot
mapfile -d '' -t terminal_args <"$terminal_log"
[[ ${terminal_args[0]} == "fedory-default-agent" && ${terminal_args[1]} == "--install" && ${terminal_args[2]} == "copilot" ]] ||
  fail "missing agent installation opens in a terminal"
[[ ! -s $notification_history ]] || fail "missing agent installation skips notifications"
[[ ! -s $agent_open_log ]] || fail "missing agent installation waits to open the agent"
[[ $(fedory-default-agent) == "pi" ]] || fail "missing agent installation waits to change the selection"

fedory-default-agent --install github-copilot >"$test_tmp/install-output"
mapfile -d '' -t mise_args <"$mise_log"
[[ ${mise_args[0]} == "use" && ${mise_args[1]} == "-g" && ${mise_args[2]} == "copilot" ]] ||
  fail "visible agent installation activates the provider globally through mise"
[[ $(fedory-default-agent) == "copilot" ]] || fail "visible agent installation changes the selection after mise succeeds"
[[ ! -s $notification_history ]] || fail "visible agent installation leaves progress to the terminal"
[[ $(<"$test_tmp/install-output") == $'\033[2J\033[3J\033[H' ]] ||
  fail "visible agent installation clears its terminal before opening the agent"
mapfile -d '' -t agent_open_args <"$agent_open_log"
[[ ${#agent_open_args[@]} == 2 && ${agent_open_args[0]} == "fedory-launch-agent" && ${agent_open_args[1]} == "--inline" ]] ||
  fail "newly installed agent opens in the installation terminal"
pass "missing agents install visibly and open in the same terminal"

: >"$notification_history"
: >"$agent_open_log"
: >"$terminal_log"
FEDORY_TEST_AGENT_INSTALLED=true fedory-default-agent github-copilot
[[ ! -s $terminal_log ]] || fail "installed agent selection skips the terminal"
[[ ! -s $notification_history ]] || fail "installed agent selection skips notifications"
mapfile -d '' -t mise_args <"$mise_log"
[[ ${mise_args[0]} == "use" && ${mise_args[1]} == "-g" && ${mise_args[2]} == "copilot" ]] ||
  fail "default agent still activates an installed provider globally through mise"
mapfile -d '' -t agent_open_args <"$agent_open_log"
[[ ${#agent_open_args[@]} == 1 && ${agent_open_args[0]} == "fedory-launch-agent" ]] ||
  fail "installed agent opens in a new terminal after selection"
pass "installed agents select and open without notifications"

: >"$agent_open_log"
if fedory-default-agent unsupported >"$test_tmp/invalid-output" 2>&1; then
  fail "default agent rejects unsupported providers"
fi
grep -F "Usage: fedory-default-agent" "$test_tmp/invalid-output" >/dev/null ||
  fail "default agent explains supported providers"
[[ $(fedory-default-agent) == "copilot" ]] || fail "invalid selection preserves the current default agent"
[[ ! -s $agent_open_log ]] || fail "invalid selection does not open an agent"
pass "default agent rejects unsupported providers without changing the selection"

: >"$notification_history"
: >"$agent_open_log"
if FEDORY_TEST_MISE_FAIL=true fedory-default-agent --install codex >"$test_tmp/install-failure-output" 2>&1; then
  fail "default agent rejects a failed mise installation"
fi
[[ $(fedory-default-agent) == "copilot" ]] || fail "failed installation preserves the current default agent"
grep -F "Could not install Codex with mise" "$test_tmp/install-failure-output" >/dev/null ||
  fail "default agent reports a failed mise installation in the terminal"
[[ ! -s $notification_history ]] || fail "failed visible agent installation skips notifications"
[[ ! -s $agent_open_log ]] || fail "failed installation does not open an agent"
pass "default agent opens only after mise installs the provider"

: >"$notification_history"
: >"$agent_open_log"
if FEDORY_TEST_AGENT_INSTALLED=true FEDORY_TEST_MISE_FAIL=true fedory-default-agent codex >"$test_tmp/setup-failure-output" 2>&1; then
  fail "default agent rejects a failed mise activation"
fi
[[ $(fedory-default-agent) == "copilot" ]] || fail "failed activation preserves the current default agent"
grep -F "Could not set Codex as the default coding agent" "$test_tmp/setup-failure-output" >/dev/null ||
  fail "default agent reports a failed activation for an installed provider"
[[ ! -s $notification_history ]] || fail "failed activation skips notifications"
[[ ! -s $agent_open_log ]] || fail "failed activation does not open an agent"
pass "default agent reports mise failures without notifications"

rm "$mock_bin/fedory-launch-agent"
hash -r

assert_launch() {
  local agent=$1
  shift
  local expected=("$@")

  printf '%s\n' "$agent" >"$agent_file"
  fedory-launch-agent "Review this" project
  mapfile -d '' -t actual <"$launch_log"

  (( ${#actual[@]} == ${#expected[@]} )) ||
    fail "$agent launch has the expected argument count" "expected: ${expected[*]}\nactual: ${actual[*]}"

  for ((index = 0; index < ${#expected[@]}; index++)); do
    [[ ${actual[$index]} == ${expected[$index]} ]] ||
      fail "$agent launch forwards the interactive prompt" "expected: ${expected[*]}\nactual: ${actual[*]}"
  done
}

assert_launch pi pi -- "Review this project"
assert_launch omp omp -- "Review this project"
assert_launch opencode opencode --prompt "Review this project"
assert_launch claude claude -- "Review this project"
assert_launch codex codex -- "Review this project"
assert_launch crush crush run "Review this project"
assert_launch grok grok -- "Review this project"
assert_launch gemini gemini --prompt-interactive "Review this project"
assert_launch copilot copilot --interactive "Review this project"
pass "agent launcher adapts initial prompts for every supported agent"

printf '%s\n' "opencode" >"$agent_file"
fedory-launch-agent
mapfile -d '' -t launch_args <"$launch_log"
[[ ${#launch_args[@]} == 1 && ${launch_args[0]} == "opencode" ]] ||
  fail "agent launcher starts the selected agent without an initial prompt"
pass "agent launcher starts the selected agent without an initial prompt"

fedory-launch-agent --inline "Review this project"
mapfile -d '' -t inline_args <"$inline_log"
[[ ${inline_args[0]} == "opencode" && ${inline_args[1]} == "--prompt" && ${inline_args[2]} == "Review this project" ]] ||
  fail "inline agent launcher runs in the current terminal"
pass "inline agent launcher runs in the current terminal"

printf '%s\n' "missing" >"$agent_file"
if FEDORY_TEST_MISSING_COMMAND=missing fedory-launch-agent >"$test_tmp/missing-output" 2>&1; then
  fail "agent launcher rejects a missing default command"
fi
grep -F "missing is not installed" "$test_tmp/missing-output" >/dev/null ||
  fail "agent launcher explains when the default command is missing"
pass "agent launcher reports a missing default command"
