# The Vivobook S15 (X1P-42-100, asus,vivobook-s15-x1p4) video codec fails its
# firmware open with EINVAL. WirePlumber's V4L2 monitor waits on that open and
# then never links audio sinks. Cameras on this laptop use libcamera, so the
# codec stays out of WirePlumber. Other Snapdragon X laptops keep the device:
# their video decode goes through the same node when its firmware loads.

wireplumber_dir=${OMARCHY_VIVOBOOK_S15_WIREPLUMBER_DIR:-/etc/wireplumber/wireplumber.conf.d}

if omarchy-hw-aarch64-qualcomm && omarchy-hw-match-device-tree asus,vivobook-s15-x1p4; then
  mkdir -p "$wireplumber_dir"
  cat >"$wireplumber_dir/50-omarchy-vivobook-s15-disable-iris.conf" <<'CONF'
# The qcom-iris video codec on the ASUS Vivobook S15 (X1P-42-100) is not a
# camera. Opening it from WirePlumber's V4L2 monitor fails with EINVAL and the
# create-device hook never completes, so later audio events never run.
# Cameras on this laptop use libcamera.
monitor.v4l2.rules = [
  {
    matches = [
      { device.name = "~v4l2_device.platform-aa00000.video-codec*" }
    ]
    actions = { update-props = { device.disabled = true } }
  }
]
CONF
fi
