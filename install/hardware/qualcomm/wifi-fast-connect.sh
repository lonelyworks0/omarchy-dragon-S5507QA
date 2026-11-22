# Reconnect Wi-Fi as soon as the device is up on Snapdragon X and ath12k.
#
# NetworkManager waits for a scan before auto-activating a known network. On
# these machines the device is ready immediately and that scan takes about 16
# seconds, while the connect itself takes about half a second.
#
# Installed only on a Qualcomm machine whose device tree names qcom,x1e80100
# or qcom,x1p42100, or whose ath12k driver is loaded. x86 installs are left
# alone, including an x86 machine that has ath12k.
#
# Undo:
#   sudo systemctl disable --now wifi-fast-connect.service
#   sudo rm -f /usr/local/bin/wifi-fast-connect \
#     /usr/lib/systemd/system-sleep/90-wifi-fast-resume \
#     /etc/systemd/system/wifi-fast-connect.service
#   sudo systemctl daemon-reload

set -euo pipefail

bin_dir=${OMARCHY_WIFI_FAST_BIN_DIR:-/usr/local/bin}
sleep_dir=${OMARCHY_WIFI_FAST_SLEEP_DIR:-/usr/lib/systemd/system-sleep}
unit_dir=${OMARCHY_WIFI_FAST_UNIT_DIR:-/etc/systemd/system}
module_root=${OMARCHY_SYS_MODULE:-/sys/module}
pci_drivers=${OMARCHY_PCI_DRIVERS:-/sys/bus/pci/drivers}

ath12k_driver_present() {
  if [[ -d $module_root/ath12k || -d $pci_drivers/ath12k_pci || -d $pci_drivers/ath12k ]]; then
    return 0
  fi
  lsmod 2>/dev/null | awk '$1 ~ /^ath12k/ { found = 1 } END { exit !found }'
}

# Snapdragon X is named by its SoC even when ath12k has not been loaded yet
# (an image's first boot, or hardware setup before the radio probes). Other
# Qualcomm boards are included once ath12k is the driver that bound.
wifi_fast_connect_applies() {
  omarchy-hw-aarch64-qualcomm || return 1
  if omarchy-hw-match-device-tree qcom,x1e80100 qcom,x1p42100; then
    return 0
  fi
  ath12k_driver_present
}

enable_wifi_fast_connect() {
  [[ $unit_dir == /etc/systemd/system ]] || return 0
  systemctl enable wifi-fast-connect.service
  systemctl daemon-reload || true
}

disable_wifi_fast_connect() {
  [[ $unit_dir == /etc/systemd/system ]] || return 0
  systemctl disable --now wifi-fast-connect.service || true
  systemctl daemon-reload || true
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  if (( $# > 1 )); then
    echo "Usage: wifi-fast-connect.sh [install|uninstall|applies]" >&2
    exit 1
  fi
  action=${1:-install}
else
  action=install
fi

if [[ $action == applies ]]; then
  if wifi_fast_connect_applies; then
    exit 0
  fi
  exit 1
fi

if [[ $action == uninstall ]]; then
  disable_wifi_fast_connect
  rm -f "$bin_dir/wifi-fast-connect" "$sleep_dir/90-wifi-fast-resume" "$unit_dir/wifi-fast-connect.service"
elif [[ $action == install ]]; then
  if wifi_fast_connect_applies; then
    echo "Detected Snapdragon X or ath12k Wi-Fi, reconnecting without waiting for NetworkManager's scan..."
    [[ -n ${OMARCHY_PATH:-} ]] || exit 1
    install -Dm755 "$OMARCHY_PATH/default/wifi-fast-connect" "$bin_dir/wifi-fast-connect"
    install -Dm755 "$OMARCHY_PATH/default/systemd/system-sleep/90-wifi-fast-resume" "$sleep_dir/90-wifi-fast-resume"
    install -Dm644 "$OMARCHY_PATH/default/systemd/system/wifi-fast-connect.service" "$unit_dir/wifi-fast-connect.service"
    enable_wifi_fast_connect
  fi
else
  echo "Usage: wifi-fast-connect.sh [install|uninstall|applies]" >&2
  exit 1
fi
