echo "Tune the Vivobook S15 S5507QA while the power-saver profile is active"

# Existing installs do not re-run hardware setup. The leaf is gated to this
# laptop and does nothing anywhere else.
if omarchy-hw-aarch64-qualcomm && omarchy-hw-match "S5507QA"; then
  sudo env PATH="$PATH" OMARCHY_PATH="$OMARCHY_PATH" bash "$OMARCHY_PATH/install/hardware/asus/vivobook-s5507qa-power.sh"
  runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
  if [[ ! -S $runtime/bus ]]; then
    echo "The panel service needs this user's graphical session. Run omarchy-migrate once you are logged in." >&2
    exit 1
  fi
  bash "$OMARCHY_PATH/install/user/hardware/asus/vivobook-s5507qa-power.sh"
fi
