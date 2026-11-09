echo "Suspend Snapdragon X laptops to idle instead of deep sleep"

# See install/hardware/qualcomm/sleep.sh. systemd reads the drop-in the next
# time the machine suspends, so no reboot and no service restart are needed.
if ! omarchy-hw-aarch64-qualcomm || ! omarchy-hw-match-device-tree \
  qcom,x1e78100 qcom,x1e80100 qcom,x1p42100 qcom,x1p64100; then
  exit 0
fi

# Another user on this machine may already have applied it.
if grep -Fqx "MemorySleepMode=s2idle" /etc/systemd/sleep.conf.d/omarchy-snapdragon-x-s2idle.conf 2>/dev/null; then
  exit 0
fi

sudo env PATH="$PATH" OMARCHY_PATH="$OMARCHY_PATH" bash -euo pipefail -c '
  source "$OMARCHY_PATH/install/hardware/qualcomm/sleep.sh"
'
