echo "Smoothing the boot splash graphics handoffs"

quit_override=/etc/systemd/system/plymouth-quit.service.d/fedory.conf
dracut_config=/etc/dracut.conf.d/fedory-early-kms.conf
handoff_ready=1

if [[ ! -f $quit_override ]] ||
  ! grep -qxF 'ExecStart=-/usr/bin/plymouth quit --retain-splash' "$quit_override"; then
  handoff_ready=0
fi

for card in /sys/class/drm/card[0-9]*; do
  [[ -e $card/device/driver/module ]] || continue
  driver=$(basename "$(readlink -f "$card/device/driver/module")")

  case "$driver" in
    amdgpu|i915|xe)
      if [[ ! -f $dracut_config ]] || ! grep -qwF "$driver" "$dracut_config"; then
        handoff_ready=0
      fi
      ;;
  esac
done

(( handoff_ready )) && exit 0

pkexec /usr/bin/env FEDORY_PATH="$FEDORY_PATH" \
  "$FEDORY_PATH/bin/fedory-refresh-plymouth"
