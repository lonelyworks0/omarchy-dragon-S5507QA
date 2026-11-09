echo "Keep WirePlumber from stalling on the Vivobook S15 video codec"

# See install/hardware/asus/fix-asus-vivobook-s15-wireplumber.sh. WirePlumber
# reads conf.d at startup, so each user restarts their own session's service.
if ! omarchy-hw-aarch64-qualcomm || ! omarchy-hw-match-device-tree asus,vivobook-s15-x1p4; then
  exit 0
fi

conf=/etc/wireplumber/wireplumber.conf.d/50-omarchy-vivobook-s15-disable-iris.conf
if ! grep -Fq "device.disabled = true" "$conf" 2>/dev/null; then
  sudo env PATH="$PATH" OMARCHY_PATH="$OMARCHY_PATH" bash -euo pipefail -c '
    source "$OMARCHY_PATH/install/hardware/asus/fix-asus-vivobook-s15-wireplumber.sh"
  '
fi

systemctl --user try-restart wireplumber.service 2>/dev/null || true
