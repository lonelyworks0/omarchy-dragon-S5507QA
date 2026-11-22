echo "Reconnect Wi-Fi immediately on Snapdragon X and ath12k instead of waiting for NetworkManager's scan"

# Existing installs do not re-run hardware setup. See
# install/hardware/qualcomm/wifi-fast-connect.sh. A later user finds the
# files installed and the service enabled, and does nothing.
#
# Undo:
#   sudo systemctl disable --now wifi-fast-connect.service
#   sudo rm -f /usr/local/bin/wifi-fast-connect \
#     /usr/lib/systemd/system-sleep/90-wifi-fast-resume \
#     /etc/systemd/system/wifi-fast-connect.service
#   sudo systemctl daemon-reload

hook=$OMARCHY_PATH/install/hardware/qualcomm/wifi-fast-connect.sh

if ! bash "$hook" applies; then
  exit 0
fi

script=/usr/local/bin/wifi-fast-connect
sleep_hook=/usr/lib/systemd/system-sleep/90-wifi-fast-resume
unit=/etc/systemd/system/wifi-fast-connect.service

if cmp -s "$OMARCHY_PATH/default/wifi-fast-connect" "$script" \
  && cmp -s "$OMARCHY_PATH/default/systemd/system-sleep/90-wifi-fast-resume" "$sleep_hook" \
  && cmp -s "$OMARCHY_PATH/default/systemd/system/wifi-fast-connect.service" "$unit" \
  && systemctl is-enabled --quiet wifi-fast-connect.service; then
  exit 0
fi

sudo env PATH="$PATH" OMARCHY_PATH="$OMARCHY_PATH" bash "$hook" install
