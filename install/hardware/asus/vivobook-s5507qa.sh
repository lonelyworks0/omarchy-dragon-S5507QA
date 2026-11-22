# ASUS Vivobook S 15 S5507QA (Snapdragon X Plus, x1p42100).
#
# The WSA884x speaker amps come back from a SoundWire clock stop with every
# register reading 0x21, and the speakers stay silent. Keep the qcom-soundwire
# controllers out of runtime suspend. The kernel also defaults mem_sleep to
# deep, which this firmware does not resume from, so suspend to idle. The
# speakers have no full protection path, so the speaker sink's volume is
# capped. Headphones are a different node and are left alone.
#
# DMI product S5507QA_S5507QA shares the substring S5507QA with the X Elite
# model S5507QAD. Match the X Plus device tree only.
#
# Undo: omarchy hw vivobook s5507qa uninstall

set -euo pipefail

rules_dir=${OMARCHY_VIVOBOOK_UDEV_DIR:-/etc/udev/rules.d}
sleep_dir=${OMARCHY_VIVOBOOK_SLEEP_DIR:-/etc/systemd/sleep.conf.d}
volume_dir=${OMARCHY_VIVOBOOK_WIREPLUMBER_DIR:-${OMARCHY_QUALCOMM_WIREPLUMBER_DIR:-/etc/wireplumber/wireplumber.conf.d}}
soundwire_root=${OMARCHY_SOUNDWIRE_SYSFS:-/sys/bus/platform/drivers/qcom-soundwire}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
rules_file=$rules_dir/90-vivobook-s15-soundwire-no-runtime-pm.rules
sleep_file=$sleep_dir/50-vivobook-s2idle.conf
volume_file=$volume_dir/50-vivobook-s15-speaker-volume.conf

# Sourced by hardware setup, which has no action argument. Executing the
# script is the install and uninstall path.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  if (( $# > 1 )); then
    echo "Usage: vivobook-s5507qa.sh [install|uninstall]" >&2
    exit 1
  fi
  action=${1:-install}
else
  action=install
fi

set_soundwire_power_control() {
  local value=$1 control
  [[ -d $soundwire_root ]] || return 0
  (
    shopt -s nullglob
    for control in "$soundwire_root"/*/power/control; do
      [[ -w $control ]] || continue
      printf '%s\n' "$value" >"$control" || true
    done
  )
}

reload_udev_rules() {
  if [[ $rules_dir == /etc/udev/rules.d ]]; then
    udevadm control --reload-rules || true
  fi
}

if [[ $action == uninstall ]]; then
  rm -f "$rules_file" "$sleep_file" "$volume_file"
  reload_udev_rules
  # auto is the kernel default these controllers had before the rule.
  set_soundwire_power_control auto
elif [[ $action == install ]]; then
  if omarchy-hw-aarch64-qualcomm && omarchy-hw-match-device-tree asus,vivobook-s15-x1p4; then
    echo "Detected ASUS Vivobook S 15 S5507QA (Snapdragon X Plus), keeping SoundWire amps powered, capping speaker volume, and suspending to idle..."
    install -Dm644 "$script_dir/90-vivobook-s15-soundwire-no-runtime-pm.rules" "$rules_file"
    install -Dm644 "$script_dir/50-vivobook-s2idle.conf" "$sleep_file"
    install -Dm644 "$script_dir/50-vivobook-s15-speaker-volume.conf" "$volume_file"
    reload_udev_rules
    set_soundwire_power_control on
  fi
else
  echo "Usage: vivobook-s5507qa.sh [install|uninstall]" >&2
  exit 1
fi
