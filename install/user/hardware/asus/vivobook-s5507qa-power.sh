# Enable the panel half of the Vivobook S15 power-saver tuning. The system
# half is installed by install/hardware/asus/vivobook-s5507qa-power.sh, which
# has already published the user unit on this machine. With no session bus
# (the install chroot) there is nothing to enable yet; first login does it.

set -euo pipefail

if omarchy-hw-aarch64-qualcomm && omarchy-hw-match "S5507QA"; then
  runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
  if [[ -S $runtime/bus ]]; then
    systemctl --user disable --now vivobook-power-display.service 2>/dev/null || true
    systemctl --user daemon-reload
    systemctl --user enable omarchy-vivobook-power-display.service
    if [[ -n ${WAYLAND_DISPLAY:-} ]]; then
      systemctl --user restart omarchy-vivobook-power-display.service || true
    fi
  fi
fi
