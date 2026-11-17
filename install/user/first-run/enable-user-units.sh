#!/bin/bash

# Enable AND start the user systemd units we ship. Runs at first-run rather
# than at finalize-user time because the user manager isn't live during the
# ISO chroot — by first-run, the Hyprland/uwsm session is up and
# `systemctl --user enable --now` both writes the correct .wants symlinks
# (based on each unit's [Install]/WantedBy) and starts the services so the
# first session has bluetooth pairing, sleep lock, etc. live immediately
# instead of waiting for the next login. ConditionPath* in the unit files
# keep the enabled units inert on hardware they don't apply to.

set -euo pipefail

omarchy-input-method configure --defaults || echo "Input method defaults deferred; run omarchy setup input after login." >&2

systemctl --user daemon-reload

# One at a time: given a list, systemctl enables none of it when it cannot find
# one unit, and that should not cost the session its bluetooth agent as well.
failed=0
for unit in \
  bt-agent.service \
  owed.service \
  omarchy-recover-internal-monitor.service \
  omarchy-sleep-lock.service \
  omarchy-migrate-notify.service \
  omarchy-fcitx5.service \
  omarchy-crash-watch.service; do
  systemctl --user enable --now "$unit" || failed=1
done

# The unit file is published only on this laptop. Anywhere else the check is
# false and first-run does not look for it.
if command -v omarchy-hw-aarch64-qualcomm >/dev/null 2>&1 \
  && command -v omarchy-hw-match >/dev/null 2>&1 \
  && omarchy-hw-aarch64-qualcomm \
  && omarchy-hw-match "S5507QA"; then
  systemctl --user enable --now omarchy-vivobook-power-display.service || failed=1
fi

omarchy-hook-install theme-set /usr/share/owe/10-owe-sync
exit "$failed"
