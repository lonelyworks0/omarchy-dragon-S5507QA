# ASUS Vivobook S 15 S5507QA (Snapdragon X Plus, x1p42100).
#
# DMI product S5507QA_S5507QA also matches a search for S5507QA, and so does
# the X Elite model S5507QAD. The device tree is what tells them apart:
# asus,vivobook-s15-x1p4 is this machine.
#
# Board firmware is asus-vivobook-s15-firmware. qualcomm/firmware.sh has
# already decided whether to hold the DSP driver, so a package installed
# here runs that decision again. The package reached Omarchy's edge channel
# before stable and rc; a channel that does not have it yet is a warning,
# not a failed install. Speaker, suspend, and the volume cap still apply.
#
# Undo: omarchy hw vivobook s5507qa uninstall
# The firmware package stays installed. Drop it with:
# omarchy pkg drop asus-vivobook-s15-firmware

if [[ -z ${OMARCHY_INSTALL:-} && -z ${OMARCHY_PATH:-} ]]; then
  echo "fix-asus-vivobook-s15-xplus: OMARCHY_PATH is not set" >&2
  exit 1
fi

install_root=${OMARCHY_INSTALL:-$OMARCHY_PATH/install}
firmware_pkg=asus-vivobook-s15-firmware

if omarchy-hw-aarch64-qualcomm && omarchy-hw-match-device-tree asus,vivobook-s15-x1p4; then
  echo "Detected ASUS Vivobook S 15 S5507QA (Snapdragon X Plus)..."

  if pacman -T "$firmware_pkg" >/dev/null; then
    :
  elif package=$(pacman -Sp --print-format %n "$firmware_pkg" 2>/dev/null); then
    omarchy-pkg-add "$package"
    # qualcomm/firmware.sh already ran, and holds the DSP driver when the
    # signed images were not there yet. Decide again now that they can be.
    # shellcheck source=install/hardware/qualcomm/firmware.sh
    source "$install_root/hardware/qualcomm/firmware.sh"
  else
    echo "asus-vivobook-s15-firmware is not in this package channel. It is published to edge before it reaches stable and rc. When the package is available, run: omarchy hw vivobook s5507qa install"
  fi

  bash "$install_root/hardware/asus/vivobook-s5507qa.sh" install
fi
