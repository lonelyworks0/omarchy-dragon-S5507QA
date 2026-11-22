# GStreamer's v4l2h264dec, v4l2h265dec, and v4l2vp9dec open the Snapdragon
# iris stateful decoder. mpv's hwdec line is per user and is applied by
# omarchy-install-video-decode.

if omarchy-hw-aarch64-qualcomm; then
  omarchy-pkg-add gst-plugins-good
fi
