#!/bin/bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

run_node_test <<'JS'
const fs = require('fs')
const bluetoothPanel = fs.readFileSync(root + '/shell/plugins/panels/bluetooth/Panel.qml', 'utf8')
const tailscalePanel = fs.readFileSync(root + '/shell/plugins/panels/tailscale/Panel.qml', 'utf8')

assert(/IpcHandler[\s\S]*?function toggleBluetooth\(\) \{ root\.toggleBluetooth\(\) \}/.test(bluetoothPanel), 'bluetooth exposes the radio toggle over IPC')
assert(/manageIpc: false/.test(bluetoothPanel), 'bluetooth owns its extended IPC handler')
assert(/function toggleTailscale\(\): string \{ tailscale\.toggleTailscale\(\); return "ok" \}/.test(tailscalePanel), 'tailscale exposes the connection toggle over IPC')
JS
