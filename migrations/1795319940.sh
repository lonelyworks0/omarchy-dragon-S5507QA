echo "Install GStreamer's V4L2 decoders on Snapdragon machines and hide the iris decoder from PipeWire without disabling it"

# Existing installs do not re-run hardware setup. gst-plugins-good is what
# provides v4l2h264dec, v4l2h265dec, and v4l2vp9dec. The WirePlumber rule
# shipped earlier as 50-disable-qcom-iris-v4l2.conf; the same rule now lives
# under a name that says it only hides the decoder from PipeWire's camera
# list. A later user finds the package and the new file already in place.

if omarchy-hw-aarch64-qualcomm; then
  omarchy-pkg-add gst-plugins-good

  iris_old=/etc/wireplumber/wireplumber.conf.d/50-disable-qcom-iris-v4l2.conf
  iris=/etc/wireplumber/wireplumber.conf.d/50-hide-qcom-iris-v4l2.conf
  if [[ -e $iris_old ]] || ! cmp -s "$OMARCHY_PATH/install/hardware/qualcomm/50-hide-qcom-iris-v4l2.conf" "$iris"; then
    sudo env PATH="$PATH" OMARCHY_PATH="$OMARCHY_PATH" bash "$OMARCHY_PATH/install/hardware/qualcomm/disable-iris-v4l2.sh" install
    systemctl --user try-restart wireplumber.service 2>/dev/null || true
  fi
fi
