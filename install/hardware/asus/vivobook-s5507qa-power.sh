# ASUS Vivobook S 15 S5507QA (Snapdragon X Plus X1P-42-100).
#
# power-profiles-daemon has no platform driver here (placeholder, SCMI cpufreq,
# no energy-performance preference). Its power-saver profile only lowers
# scaling_max_freq, to 1.92 GHz on this CPU. On battery that measured
# 9.64 W against 9.95 W balanced and 10.72 W performance, and the cap stalls
# a burst of Chromium tabs. The panel is a 120 Hz OLED with no self-refresh
# yet, Wi-Fi power save is pinned off by Omarchy's NetworkManager drop-in,
# and the Adreno devfreq is uncapped.
#
# While power-saver is active, the system service raises the CPU ceiling to
# the balanced level, caps the GPU, and turns Wi-Fi power save on. The user
# service drops the internal panel's refresh. Leaving power-saver restores
# the GPU, Wi-Fi, and the panel mode from before the switch. The CPU ceiling
# is power-profiles-daemon's again as soon as the profile changes.
#
# Undo: omarchy power vivobook uninstall

set -euo pipefail

conf=${OMARCHY_VIVOBOOK_CONF:-/etc/omarchy/vivobook-s5507qa-power.conf}
systemd_dir=${OMARCHY_VIVOBOOK_SYSTEMD_DIR:-/etc/systemd/system}
user_systemd_dir=${OMARCHY_VIVOBOOK_USER_SYSTEMD_DIR:-/etc/systemd/user}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if omarchy-hw-aarch64-qualcomm && omarchy-hw-match "S5507QA"; then
  echo "Detected ASUS Vivobook S 15 S5507QA, applying power-saver tuning..."

  # The standalone prototype watches the same profile. One watcher is enough.
  systemctl disable --now vivobook-power.service 2>/dev/null || true

  if [[ ! -e $conf ]]; then
    install -Dm644 "$script_dir/vivobook-s5507qa-power.conf" "$conf"
  fi
  install -Dm644 "$script_dir/omarchy-vivobook-power.service" "$systemd_dir/omarchy-vivobook-power.service"
  install -Dm644 "$script_dir/omarchy-vivobook-power-display.service" "$user_systemd_dir/omarchy-vivobook-power-display.service"

  systemctl daemon-reload || true
  systemctl enable omarchy-vivobook-power.service

  booted=0
  if [[ -n ${OMARCHY_VIVOBOOK_BOOTED:-} ]]; then
    booted=$OMARCHY_VIVOBOOK_BOOTED
  elif [[ -d /run/systemd/system ]]; then
    booted=1
  fi
  if [[ $booted == 1 ]]; then
    systemctl restart omarchy-vivobook-power.service || true
  fi
fi
