echo "Install Snapdragon X Plus firmware, speaker fixes, and suspend-to-idle on the ASUS Vivobook S 15 S5507QA"

# Existing installs do not re-run hardware setup. The X Plus is the device
# tree asus,vivobook-s15-x1p4. S5507QAD contains the string S5507QA and is a
# different machine, so this does not match it. A later user finds the files
# and the package already in place.
#
# A channel that does not carry asus-vivobook-s15-firmware yet (it is
# published to edge first) still gets the speaker, suspend, and volume cap.
# The firmware install is retried with: omarchy hw vivobook s5507qa install

if omarchy-hw-aarch64-qualcomm && omarchy-hw-match-device-tree asus,vivobook-s15-x1p4; then
  rules=/etc/udev/rules.d/90-vivobook-s15-soundwire-no-runtime-pm.rules
  sleep_conf=/etc/systemd/sleep.conf.d/50-vivobook-s2idle.conf
  volume=/etc/wireplumber/wireplumber.conf.d/50-vivobook-s15-speaker-volume.conf
  shipped=$OMARCHY_PATH/install/hardware/asus
  firmware_pkg=asus-vivobook-s15-firmware
  need=0

  if ! cmp -s "$shipped/90-vivobook-s15-soundwire-no-runtime-pm.rules" "$rules" \
    || ! cmp -s "$shipped/50-vivobook-s2idle.conf" "$sleep_conf" \
    || ! cmp -s "$shipped/50-vivobook-s15-speaker-volume.conf" "$volume"; then
    need=1
  fi

  if ! pacman -T "$firmware_pkg" >/dev/null; then
    if pacman -Sp --print-format %n "$firmware_pkg" >/dev/null 2>&1; then
      need=1
    elif (( need == 0 )); then
      echo "asus-vivobook-s15-firmware is not in this package channel. It is published to edge before it reaches stable and rc. When the package is available, run: omarchy hw vivobook s5507qa install"
    fi
  fi

  if (( need == 1 )); then
    sudo env PATH="$PATH" OMARCHY_PATH="$OMARCHY_PATH" OMARCHY_INSTALL="$OMARCHY_PATH/install" \
      bash -euo pipefail -c 'source "$OMARCHY_PATH/install/hardware/asus/fix-asus-vivobook-s15-xplus.sh"'
  fi
fi
