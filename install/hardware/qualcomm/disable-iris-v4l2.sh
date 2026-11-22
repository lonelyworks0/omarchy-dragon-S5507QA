# Hide the Snapdragon iris decoder from PipeWire's camera list. This does
# not disable hardware decoding: mpv, GStreamer, and any other client can
# still open the V4L2 device.
#
# The qcom-iris codec at platform aa00000 is not a camera. WirePlumber's
# V4L2 monitor opens it, that open fails with EINVAL, and the async
# create-device hook never finishes, so the event dispatcher stalls and no
# audio sinks get linked. Cameras on these laptops are libcamera devices,
# so WirePlumber skips that node.
#
# The node address is the same on Qualcomm X1 machines. A Qualcomm machine
# without it is unchanged, because the rule matches that name only.
#
# The drop-in used to be installed as 50-disable-qcom-iris-v4l2.conf. That
# name reads as if decoding were turned off, so the rule now ships as
# 50-hide-qcom-iris-v4l2.conf. This script keeps its filename because
# migration 1795310400.sh calls this path.
#
# Undo: omarchy hw vivobook s5507qa uninstall

set -euo pipefail

wireplumber_dir=${OMARCHY_QUALCOMM_WIREPLUMBER_DIR:-/etc/wireplumber/wireplumber.conf.d}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
iris_file=$wireplumber_dir/50-hide-qcom-iris-v4l2.conf
# The name shipped before this rule was described as a hide, not a disable.
iris_file_retired=$wireplumber_dir/50-disable-qcom-iris-v4l2.conf

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  if (( $# > 1 )); then
    echo "Usage: disable-iris-v4l2.sh [install|uninstall]" >&2
    exit 1
  fi
  action=${1:-install}
else
  action=install
fi

if [[ $action == uninstall ]]; then
  rm -f "$iris_file" "$iris_file_retired"
elif [[ $action == install ]]; then
  if omarchy-hw-aarch64-qualcomm; then
    echo "Detected Qualcomm hardware, hiding the iris decoder from PipeWire's camera list..."
    install -Dm644 "$script_dir/50-hide-qcom-iris-v4l2.conf" "$iris_file"
    rm -f "$iris_file_retired"
  fi
else
  echo "Usage: disable-iris-v4l2.sh [install|uninstall]" >&2
  exit 1
fi
