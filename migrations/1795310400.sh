echo "Keep the Vivobook S15 speakers awake, suspend it to idle, and stop WirePlumber opening the Qualcomm video codec"

# Existing installs do not re-run hardware setup. The speaker and suspend
# leaves apply only to the Vivobook S 15 S5507QA. The WirePlumber leaf applies
# to every Qualcomm machine. A later user on the same machine finds the files
# already installed and does not write them again.

rules=/etc/udev/rules.d/90-vivobook-s15-soundwire-no-runtime-pm.rules
sleep_conf=/etc/systemd/sleep.conf.d/50-vivobook-s2idle.conf
iris=/etc/wireplumber/wireplumber.conf.d/50-disable-qcom-iris-v4l2.conf

if omarchy-hw-aarch64-qualcomm && omarchy-hw-match "S5507QA"; then
  if ! cmp -s "$OMARCHY_PATH/install/hardware/asus/90-vivobook-s15-soundwire-no-runtime-pm.rules" "$rules" \
    || ! cmp -s "$OMARCHY_PATH/install/hardware/asus/50-vivobook-s2idle.conf" "$sleep_conf"; then
    sudo env PATH="$PATH" OMARCHY_PATH="$OMARCHY_PATH" bash "$OMARCHY_PATH/install/hardware/asus/vivobook-s5507qa.sh" install
  fi
fi

if omarchy-hw-aarch64-qualcomm; then
  if ! cmp -s "$OMARCHY_PATH/install/hardware/qualcomm/50-disable-qcom-iris-v4l2.conf" "$iris"; then
    sudo env PATH="$PATH" OMARCHY_PATH="$OMARCHY_PATH" bash "$OMARCHY_PATH/install/hardware/qualcomm/disable-iris-v4l2.sh" install
  fi
  # Each user restarts their own session. WirePlumber reads conf.d at startup.
  systemctl --user try-restart wireplumber.service 2>/dev/null || true
fi
