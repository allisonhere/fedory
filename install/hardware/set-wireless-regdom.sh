# Persist wireless regulatory domain based on the target timezone. Install is
# followed by reboot, so don't mutate live Wi-Fi state with `iw reg set`.
#
# /etc/conf.d/wireless-regdom is read by the wireless-regdb package's own
# regdomain integration on Arch; whether Fedora's wireless-regdb package
# ships the same conf.d convention hasn't been independently verified here
# -- this leaf is a no-op (see the guard below) on any system where the
# file doesn't already exist, so it's safe either way, but don't assume
# this is actually wired up on Fedora without checking.
regdom_file=/etc/conf.d/wireless-regdom
[[ -f $regdom_file ]] || exit 0

if grep -q '^WIRELESS_REGDOM=' "$regdom_file"; then
  exit 0
fi

timezone=""
if [[ -e /etc/localtime ]]; then
  timezone=$(readlink -f /etc/localtime || true)
  timezone=${timezone#/usr/share/zoneinfo/}
fi

country="${timezone%%/*}"
zone_tab=/usr/share/zoneinfo/zone.tab
if [[ ! $country =~ ^[A-Z]{2}$ && -n $timezone && -f $zone_tab ]]; then
  country=$(awk -v tz="$timezone" '$3 == tz {print $1; exit}' "$zone_tab")
fi

if [[ $country =~ ^[A-Z]{2}$ ]]; then
  echo "WIRELESS_REGDOM=\"$country\"" | sudo tee -a "$regdom_file" >/dev/null
fi
