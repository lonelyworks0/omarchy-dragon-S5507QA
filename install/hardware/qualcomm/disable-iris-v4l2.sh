# The Snapdragon qcom-iris video codec at platform aa00000 is not a camera.
# WirePlumber's V4L2 monitor opens it, that open fails with EINVAL, and the
# async create-device hook never finishes, so the event dispatcher stalls and
# no audio sinks get linked. Cameras on these laptops are handled by
# libcamera, so WirePlumber skips that node. Other clients can still open it.
#
# The node address is the same on Qualcomm X1 machines. A Qualcomm machine
# without it is unchanged, because the rule matches that name only.
#
# Undo: omarchy hw vivobook s5507qa uninstall

set -euo pipefail

wireplumber_dir=${OMARCHY_QUALCOMM_WIREPLUMBER_DIR:-/etc/wireplumber/wireplumber.conf.d}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
iris_file=$wireplumber_dir/50-disable-qcom-iris-v4l2.conf

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
  rm -f "$iris_file"
elif [[ $action == install ]]; then
  if omarchy-hw-aarch64-qualcomm; then
    echo "Detected Qualcomm hardware, keeping WirePlumber off the iris video codec..."
    install -Dm644 "$script_dir/50-disable-qcom-iris-v4l2.conf" "$iris_file"
  fi
else
  echo "Usage: disable-iris-v4l2.sh [install|uninstall]" >&2
  exit 1
fi
