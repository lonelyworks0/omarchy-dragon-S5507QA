#!/bin/bash
# shellcheck disable=SC1090,SC1091,SC2317

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

command=$ROOT/bin/omarchy-power-vivobook
setup=$ROOT/install/hardware/asus/vivobook-s5507qa-power.sh
user_setup=$ROOT/install/user/hardware/asus/vivobook-s5507qa-power.sh
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin"

for script in "$command" "$setup" "$user_setup" \
  "$ROOT/install/user/first-run/enable-user-units.sh" \
  "$ROOT"/migrations/1794878507.sh; do
  bash -n "$script" || fail "Vivobook power scripts have valid syntax" "$script"
done
pass "Vivobook power scripts have valid syntax"

cat >"$scratch/bin/omarchy-hw-aarch64-qualcomm" <<'EOF'
#!/bin/bash
[[ ${FAKE_VIVOBOOK:-0} == 1 ]]
EOF
cat >"$scratch/bin/omarchy-hw-match" <<'EOF'
#!/bin/bash
[[ ${FAKE_VIVOBOOK:-0} == 1 && $1 == S5507QA ]]
EOF
cat >"$scratch/bin/busctl" <<'EOF'
#!/bin/bash
[[ ${FAKE_BUSCTL_FAIL:-0} == 1 ]] && exit 1
if [[ $1 == get-property ]]; then
  printf 's "%s"\n' "${FAKE_PROFILE:-balanced}"
fi
EOF
cat >"$scratch/bin/iw" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${IW_LOG:?}"
EOF
cat >"$scratch/bin/systemctl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${SYSTEMCTL_LOG:?}"
if [[ $* == *is-active* ]]; then
  printf 'inactive\n'
fi
EOF
cat >"$scratch/bin/powerprofilesctl" <<'EOF'
#!/bin/bash
if [[ $1 == get ]]; then
  printf '%s\n' "${PPD_PROFILE:-power-saver}"
elif [[ $1 == set ]]; then
  printf '%s\n' "$2" >>"${PPD_LOG:?}"
else
  exit 1
fi
EOF
cat >"$scratch/bin/hyprctl" <<'EOF'
#!/bin/bash
if [[ $1 == monitors && $2 == -j ]]; then
  cat "${MONITORS_JSON:?}"
elif [[ $1 == eval ]]; then
  printf '%s\n' "$2" >>"${HYPR_LOG:?}"
else
  echo "unexpected hyprctl: $*" >&2
  exit 1
fi
EOF
chmod +x "$scratch/bin/"*

export PATH="$scratch/bin:$ROOT/bin:$PATH"
export IW_LOG="$scratch/iw.log"
export SYSTEMCTL_LOG="$scratch/systemctl.log"
export PPD_LOG="$scratch/ppd.log"
export HYPR_LOG="$scratch/hypr.log"
export OMARCHY_VIVOBOOK_PPD_SETTLE=0
export OMARCHY_VIVOBOOK_PROFILE_SETTLE=0
: >"$IW_LOG"
: >"$SYSTEMCTL_LOG"
: >"$PPD_LOG"
: >"$HYPR_LOG"

cpu_root=$scratch/cpufreq
gpu_root=$scratch/devfreq
gpu=$gpu_root/3d00000.gpu
net_root=$scratch/net
mkdir -p "$cpu_root/policy0" "$cpu_root/policy1" "$gpu" "$net_root/wlan0/wireless" "$net_root/eth0"
printf '3400000\n' >"$cpu_root/policy0/cpuinfo_max_freq"
printf '1920000\n' >"$cpu_root/policy0/scaling_max_freq"
printf '2000000\n' >"$cpu_root/policy1/cpuinfo_max_freq"
printf '1920000\n' >"$cpu_root/policy1/scaling_max_freq"
printf '280000000 380000000 550000000 666000000 1107000000\n' >"$gpu/available_frequencies"
printf '1107000000\n' >"$gpu/max_freq"

sysfs_env=(
  OMARCHY_VIVOBOOK_CPUFREQ_ROOT="$cpu_root"
  OMARCHY_VIVOBOOK_DEVFREQ_ROOT="$gpu_root"
  OMARCHY_VIVOBOOK_NET_ROOT="$net_root"
)
# Keep the command off any config installed on the machine running the test.
export OMARCHY_VIVOBOOK_CONF=$scratch/no-such.conf

FAKE_VIVOBOOK=1 FAKE_PROFILE=power-saver \
  env "${sysfs_env[@]}" "$command" apply >/dev/null
[[ $(<"$cpu_root/policy0/scaling_max_freq") == 2611200 ]] ||
  fail "power-saver raises the CPU ceiling to the balanced level"
[[ $(<"$cpu_root/policy1/scaling_max_freq") == 2000000 ]] ||
  fail "power-saver clamps the CPU ceiling to each policy's hardware max"
[[ $(<"$gpu/max_freq") == 666000000 ]] ||
  fail "power-saver caps the GPU at 666 MHz"
[[ $(<"$IW_LOG") == "dev wlan0 set power_save on" ]] ||
  fail "power-saver enables Wi-Fi power save on wireless interfaces only"
pass "power-saver raises the CPU ceiling, caps the GPU, and enables Wi-Fi power save"

: >"$IW_LOG"
FAKE_VIVOBOOK=1 FAKE_PROFILE=balanced \
  env "${sysfs_env[@]}" "$command" apply >/dev/null
[[ $(<"$cpu_root/policy0/scaling_max_freq") == 2611200 ]] ||
  fail "leaving power-saver leaves the CPU ceiling to power-profiles-daemon"
[[ $(<"$gpu/max_freq") == 1107000000 ]] ||
  fail "leaving power-saver clears the GPU cap"
[[ $(<"$IW_LOG") == "dev wlan0 set power_save off" ]] ||
  fail "leaving power-saver turns Wi-Fi power save off"
pass "leaving power-saver restores the GPU and Wi-Fi power save"

printf '1920000\n' >"$cpu_root/policy0/scaling_max_freq"
printf '1107000000\n' >"$gpu/max_freq"
: >"$IW_LOG"
FAKE_VIVOBOOK=0 FAKE_PROFILE=power-saver \
  env "${sysfs_env[@]}" "$command" apply >/dev/null
[[ $(<"$cpu_root/policy0/scaling_max_freq") == 1920000 ]] ||
  fail "other machines keep power-profiles-daemon's CPU ceiling"
[[ $(<"$gpu/max_freq") == 1107000000 ]] ||
  fail "other machines are not given a GPU cap"
[[ ! -s $IW_LOG ]] || fail "other machines are not given a Wi-Fi power-save change"
pass "the tuning does nothing on other machines"

FAKE_BUSCTL_FAIL=1 FAKE_VIVOBOOK=1 \
  env "${sysfs_env[@]}" "$command" apply >/dev/null
[[ $(<"$cpu_root/policy0/scaling_max_freq") == 1920000 ]] ||
  fail "a missing power profile does not rewrite the CPU ceiling"
unset FAKE_BUSCTL_FAIL
pass "a missing power profile leaves the knobs alone"

empty_conf=$scratch/empty.conf
printf 'CPU_CAP_KHZ=\nGPU_CAP_HZ=666000000\nWIFI_POWERSAVE=0\nPANEL_SAVER_HZ=60\n' >"$empty_conf"
printf '1920000\n' >"$cpu_root/policy0/scaling_max_freq"
printf '1107000000\n' >"$gpu/max_freq"
: >"$IW_LOG"
FAKE_VIVOBOOK=1 FAKE_PROFILE=power-saver OMARCHY_VIVOBOOK_CONF="$empty_conf" \
  env "${sysfs_env[@]}" "$command" apply >/dev/null
[[ $(<"$cpu_root/policy0/scaling_max_freq") == 1920000 ]] ||
  fail "an empty CPU cap leaves power-profiles-daemon's ceiling"
[[ $(<"$gpu/max_freq") == 666000000 ]] ||
  fail "the GPU cap still applies when the CPU cap is disabled"
[[ ! -s $IW_LOG ]] || fail "Wi-Fi power save stays off when the config disables it"
pass "empty CPU cap and disabled Wi-Fi power save are left alone"

snap_gpu=$scratch/snap-devfreq/3d00000.gpu
mkdir -p "$snap_gpu"
printf '280000000 550000000 720000000\n' >"$snap_gpu/available_frequencies"
printf '720000000\n' >"$snap_gpu/max_freq"
FAKE_VIVOBOOK=1 FAKE_PROFILE=power-saver \
  env OMARCHY_VIVOBOOK_CPUFREQ_ROOT="$cpu_root" \
  OMARCHY_VIVOBOOK_DEVFREQ_ROOT="$scratch/snap-devfreq" \
  OMARCHY_VIVOBOOK_NET_ROOT="$net_root" \
  "$command" apply >/dev/null
[[ $(<"$snap_gpu/max_freq") == 550000000 ]] ||
  fail "the GPU cap snaps down to an advertised frequency"
pass "the GPU cap snaps down to an advertised frequency"

write_monitors() {
  cat >"$scratch/monitors.json" <<EOF
[
  {
    "name": "DP-2",
    "width": 1920,
    "height": 1080,
    "refreshRate": 144.0,
    "x": 2880,
    "y": 0,
    "scale": 1,
    "availableModes": ["1920x1080@144.00Hz", "1920x1080@60.00Hz"]
  },
  {
    "name": "$1",
    "width": 2880,
    "height": 1620,
    "refreshRate": $2,
    "x": $3,
    "y": $4,
    "scale": $5,
    "availableModes": [$6]
  }
]
EOF
}

modes='"2880x1620@120.00Hz", "2880x1620@90.00Hz", "2880x1620@60.00Hz"'
state_dir=$scratch/state
export MONITORS_JSON=$scratch/monitors.json
export OMARCHY_VIVOBOOK_STATE_DIR=$state_dir

display_apply() {
  FAKE_VIVOBOOK=1 FAKE_PROFILE="$1" \
    OMARCHY_VIVOBOOK_CONF="${2:-$scratch/no-such.conf}" \
    "$command" display-apply
}

: >"$HYPR_LOG"
write_monitors eDP-1 90.0 0 100 1.6 "$modes"
display_apply balanced
[[ ! -s $HYPR_LOG ]] || fail "a manual refresh is left alone while power-saver is off" "$(<"$HYPR_LOG")"
[[ ! -e $state_dir/display ]] || fail "a manual refresh is not recorded as a hold"
pass "a manual refresh is left alone outside power-saver"

display_apply power-saver
[[ $(<"$HYPR_LOG") == 'hl.monitor({ output = "eDP-1", mode = "2880x1620@60", position = "0x100", scale = 1.6 })' ]] ||
  fail "power-saver lowers the internal panel and keeps its place and scale" "$(<"$HYPR_LOG")"
[[ $(<"$state_dir/display") == *'mode=2880x1620@90'* ]] ||
  fail "power-saver remembers the refresh in use before the switch" "$(<"$state_dir/display")"
pass "power-saver lowers the derived internal panel to 60 Hz"

write_monitors eDP-1 60.0 40 50 2 "$modes"
: >"$HYPR_LOG"
display_apply balanced
[[ $(<"$HYPR_LOG") == 'hl.monitor({ output = "eDP-1", mode = "2880x1620@90", position = "40x50", scale = 2 })' ]] ||
  fail "leaving power-saver restores the previous mode, not the preferred one" "$(<"$HYPR_LOG")"
[[ ! -e $state_dir/display ]] || fail "leaving power-saver drops the hold"
: >"$HYPR_LOG"
write_monitors eDP-1 90.0 40 50 2 "$modes"
display_apply balanced
[[ ! -s $HYPR_LOG ]] ||
  fail "a later pass does not override a refresh chosen outside power-saver" "$(<"$HYPR_LOG")"
pass "leaving power-saver restores the mode from before the switch"

: >"$HYPR_LOG"
rm -rf "$state_dir"
write_monitors eDP-1 60.0 0 0 1.6 "$modes"
display_apply power-saver
[[ ! -s $HYPR_LOG ]] || fail "power-saver does not retune a panel that is already at 60 Hz" "$(<"$HYPR_LOG")"
: >"$HYPR_LOG"
display_apply balanced
[[ ! -s $HYPR_LOG ]] ||
  fail "leaving power-saver does not raise a panel the user already kept at 60 Hz" "$(<"$HYPR_LOG")"
pass "a panel already at 60 Hz stays there across power-saver"

: >"$HYPR_LOG"
rm -rf "$state_dir"
write_monitors eDP-2 120.0 10 -20 2 "$modes"
display_apply power-saver
[[ $(<"$HYPR_LOG") == 'hl.monitor({ output = "eDP-2", mode = "2880x1620@60", position = "10x-20", scale = 2 })' ]] ||
  fail "the internal panel name, position, and scale come from Hyprland" "$(<"$HYPR_LOG")"
pass "the internal panel name, position, and scale come from Hyprland"

: >"$HYPR_LOG"
rm -rf "$state_dir"
printf '[\n]\n' >"$scratch/monitors.json"
display_apply power-saver
[[ ! -s $HYPR_LOG ]] || fail "an external monitor is not retuned" "$(<"$HYPR_LOG")"
pass "an external monitor is not retuned"

no_hz=$scratch/no-hz.conf
printf 'PANEL_SAVER_HZ=0\n' >"$no_hz"
: >"$HYPR_LOG"
rm -rf "$state_dir"
write_monitors eDP-1 120.0 0 0 1 "$modes"
display_apply power-saver "$no_hz"
[[ ! -s $HYPR_LOG ]] || fail "a zero panel setting leaves a manual refresh alone" "$(<"$HYPR_LOG")"
pass "a zero panel setting leaves the refresh alone"

only_120=$scratch/only-120.json
cat >"$only_120" <<'EOF'
[
  {
    "name": "eDP-1",
    "width": 2880,
    "height": 1620,
    "refreshRate": 120.0,
    "x": 0,
    "y": 0,
    "scale": 1,
    "availableModes": ["2880x1620@120.00Hz"]
  }
]
EOF
: >"$HYPR_LOG"
rm -rf "$state_dir"
MONITORS_JSON=$only_120 display_apply power-saver
[[ ! -s $HYPR_LOG ]] || fail "power-saver does not invent a 60 Hz mode" "$(<"$HYPR_LOG")"
[[ ! -e $state_dir/display ]] || fail "power-saver does not hold a panel it could not change"
pass "power-saver does not invent a 60 Hz mode"

FAKE_VIVOBOOK=0 "$command" status >"$scratch/status-other.txt"
grep -Fq 'not a Vivobook S 15 S5507QA' "$scratch/status-other.txt" ||
  fail "status says when the tuning does not apply"
pass "status says when the tuning does not apply"

install_root=$scratch/install
mkdir -p "$install_root"
(
  omarchy-hw-aarch64-qualcomm() { return 0; }
  omarchy-hw-match() { [[ $1 == S5507QA ]]; }
  systemctl() { printf '%s\n' "$*" >>"$install_root/systemctl.log"; }

  OMARCHY_VIVOBOOK_CONF="$install_root/vivobook.conf" \
    OMARCHY_VIVOBOOK_SYSTEMD_DIR="$install_root/system" \
    OMARCHY_VIVOBOOK_USER_SYSTEMD_DIR="$install_root/user" \
    OMARCHY_VIVOBOOK_BOOTED=0 \
    source "$setup"
)
[[ -f $install_root/vivobook.conf ]] || fail "setup installs the Vivobook power config"
grep -Fq 'CPU_CAP_KHZ=2611200' "$install_root/vivobook.conf" ||
  fail "setup installs the balanced CPU ceiling"
grep -Fq 'ExecStart=/usr/bin/omarchy-power-vivobook watch' \
  "$install_root/system/omarchy-vivobook-power.service" ||
  fail "setup installs the system watcher"
grep -Fq 'ExecStopPost=/usr/bin/omarchy-power-vivobook reset' \
  "$install_root/system/omarchy-vivobook-power.service" ||
  fail "stopping the system watcher clears its knobs"
grep -Fq 'ExecStart=/usr/bin/omarchy-power-vivobook display-watch' \
  "$install_root/user/omarchy-vivobook-power-display.service" ||
  fail "setup installs the panel watcher"
grep -Fq 'ExecStopPost=/usr/bin/omarchy-power-vivobook display-reset' \
  "$install_root/user/omarchy-vivobook-power-display.service" ||
  fail "stopping the panel watcher restores the held mode"
grep -Fxq 'enable omarchy-vivobook-power.service' "$install_root/systemctl.log" ||
  fail "setup enables the system watcher"
grep -Fxq 'disable --now vivobook-power.service' "$install_root/systemctl.log" ||
  fail "setup stops the standalone prototype watcher"
if grep -Fq 'restart omarchy-vivobook-power.service' "$install_root/systemctl.log"; then
  fail "setup does not restart the watcher before the machine has booted"
fi
printf 'CPU_CAP_KHZ=2000000\n' >"$install_root/vivobook.conf"
(
  omarchy-hw-aarch64-qualcomm() { return 0; }
  omarchy-hw-match() { [[ $1 == S5507QA ]]; }
  systemctl() { printf '%s\n' "$*" >>"$install_root/systemctl.log"; }
  OMARCHY_VIVOBOOK_CONF="$install_root/vivobook.conf" \
    OMARCHY_VIVOBOOK_SYSTEMD_DIR="$install_root/system" \
    OMARCHY_VIVOBOOK_USER_SYSTEMD_DIR="$install_root/user" \
    OMARCHY_VIVOBOOK_BOOTED=1 \
    source "$setup"
)
[[ $(<"$install_root/vivobook.conf") == 'CPU_CAP_KHZ=2000000' ]] ||
  fail "setup keeps an edited config"
grep -Fxq 'restart omarchy-vivobook-power.service' "$install_root/systemctl.log" ||
  fail "setup starts the watcher on a booted machine"
pass "setup installs the tuning on a Vivobook S15 and keeps an edited config"

for gate in qualcomm model; do
  missed=$scratch/missed-$gate
  mkdir -p "$missed"
  (
    if [[ $gate == qualcomm ]]; then
      omarchy-hw-aarch64-qualcomm() { return 1; }
      omarchy-hw-match() { return 0; }
    else
      omarchy-hw-aarch64-qualcomm() { return 0; }
      omarchy-hw-match() { return 1; }
    fi
    systemctl() { fail "setup does not touch systemd when the laptop does not match"; }
    OMARCHY_VIVOBOOK_CONF="$missed/vivobook.conf" \
      OMARCHY_VIVOBOOK_SYSTEMD_DIR="$missed/system" \
      OMARCHY_VIVOBOOK_USER_SYSTEMD_DIR="$missed/user" \
      OMARCHY_VIVOBOOK_BOOTED=0 \
      source "$setup"
  )
  [[ ! -e $missed/vivobook.conf ]] || fail "setup does not install a config when the laptop does not match ($gate)"
  [[ ! -e $missed/system/omarchy-vivobook-power.service ]] ||
    fail "setup does not install a service when the laptop does not match ($gate)"
done
pass "setup does nothing unless this is a Qualcomm Vivobook S15"

python3 - <<PY
import socket
path = "$scratch/bus"
sock = socket.socket(socket.AF_UNIX)
sock.bind(path)
PY
(
  omarchy-hw-aarch64-qualcomm() { return 0; }
  omarchy-hw-match() { [[ $1 == S5507QA ]]; }
  systemctl() { printf '%s\n' "$*" >>"$scratch/user-systemctl.log"; }
  XDG_RUNTIME_DIR=$scratch WAYLAND_DISPLAY=wayland-1 source "$user_setup"
)
grep -Fxq -- '--user enable omarchy-vivobook-power-display.service' "$scratch/user-systemctl.log" ||
  fail "the user setup enables the panel watcher"
grep -Fxq -- '--user disable --now vivobook-power-display.service' "$scratch/user-systemctl.log" ||
  fail "the user setup stops the standalone prototype panel watcher"
grep -Fq 'restart omarchy-vivobook-power-display.service' "$scratch/user-systemctl.log" ||
  fail "the user setup starts the panel watcher in a graphical session"
: >"$scratch/user-systemctl.log"
(
  omarchy-hw-aarch64-qualcomm() { return 0; }
  omarchy-hw-match() { return 1; }
  systemctl() { printf '%s\n' "$*" >>"$scratch/user-systemctl.log"; }
  XDG_RUNTIME_DIR=$scratch WAYLAND_DISPLAY=wayland-1 source "$user_setup"
)
[[ ! -s $scratch/user-systemctl.log ]] || fail "the user setup does nothing on other machines"
pass "the user setup enables the panel watcher only on this laptop"

cat >"$scratch/bin/omarchy-input-method" <<'EOF'
#!/bin/bash
exit 0
EOF
cat >"$scratch/bin/omarchy-hook-install" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$scratch/bin/omarchy-input-method" "$scratch/bin/omarchy-hook-install"
: >"$SYSTEMCTL_LOG"
FAKE_VIVOBOOK=1 bash "$ROOT/install/user/first-run/enable-user-units.sh" >/dev/null
grep -Fxq -- '--user enable --now omarchy-vivobook-power-display.service' "$SYSTEMCTL_LOG" ||
  fail "first login enables the panel watcher on this laptop"
: >"$SYSTEMCTL_LOG"
FAKE_VIVOBOOK=0 bash "$ROOT/install/user/first-run/enable-user-units.sh" >/dev/null
if grep -Fq 'omarchy-vivobook-power-display.service' "$SYSTEMCTL_LOG"; then
  fail "first login does not enable the panel watcher on other machines"
fi
pass "first login enables the panel watcher only on this laptop"

printf '666000000\n' >"$gpu/max_freq"
: >"$IW_LOG"
: >"$PPD_LOG"
: >"$SYSTEMCTL_LOG"
unit_system=$scratch/uninstall-system
unit_user=$scratch/uninstall-user
mkdir -p "$unit_system" "$unit_user"
printf 'system\n' >"$unit_system/omarchy-vivobook-power.service"
printf 'user\n' >"$unit_user/omarchy-vivobook-power-display.service"
uninstall_conf=$scratch/uninstall.conf
printf 'CPU_CAP_KHZ=2611200\n' >"$uninstall_conf"
env -u XDG_RUNTIME_DIR -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS \
  FAKE_VIVOBOOK=1 PPD_PROFILE=power-saver \
  OMARCHY_VIVOBOOK_CONF="$uninstall_conf" \
  OMARCHY_VIVOBOOK_SYSTEMD_DIR="$unit_system" \
  OMARCHY_VIVOBOOK_USER_SYSTEMD_DIR="$unit_user" \
  "${sysfs_env[@]}" \
  "$command" uninstall >/dev/null
[[ ! -e $unit_system/omarchy-vivobook-power.service ]] || fail "uninstall removes the system unit"
[[ ! -e $unit_user/omarchy-vivobook-power-display.service ]] || fail "uninstall removes the user unit"
[[ ! -e $uninstall_conf && -f ${uninstall_conf}.removed ]] || fail "uninstall sets the config aside"
[[ $(<"$gpu/max_freq") == 1107000000 ]] || fail "uninstall clears the GPU cap"
[[ $(<"$IW_LOG") == "dev wlan0 set power_save off" ]] || fail "uninstall turns Wi-Fi power save off"
[[ $(<"$PPD_LOG") == $'balanced\npower-saver' ]] ||
  fail "uninstall asks power-profiles-daemon to rewrite the CPU ceiling" "$(<"$PPD_LOG")"
pass "uninstall removes the tuning and restores the knobs"

bat=$scratch/power_now
printf '10000000\n' >"$bat"
: >"$PPD_LOG"
FAKE_VIVOBOOK=1 FAKE_PROFILE=balanced \
  OMARCHY_VIVOBOOK_BATTERY="$bat" \
  OMARCHY_VIVOBOOK_MEASURE_SETTLE=0 \
  OMARCHY_VIVOBOOK_MEASURE_INTERVAL=0 \
  "$command" measure 0 >"$scratch/measure.txt"
[[ $(<"$PPD_LOG") == $'performance\nbalanced\npower-saver\nbalanced' ]] ||
  fail "measure restores the profile it started from" "$(<"$PPD_LOG")"
grep -Fq 'restored: balanced' "$scratch/measure.txt" ||
  fail "measure reports the restored profile"
if FAKE_VIVOBOOK=0 "$command" measure 0 >/dev/null 2>"$scratch/measure-other.err"; then
  fail "measure refuses to switch profiles on other machines"
fi
pass "measure samples the three profiles and restores the one it started from"
