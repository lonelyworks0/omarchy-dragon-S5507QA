#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

cmd="$ROOT/bin/omarchy-update-oem-firmware"
test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mkdir -p "$test_tmp/bin" "$test_tmp/state" "$test_tmp/firmware" "$test_tmp/home"
cat >"$test_tmp/bin/omarchy-hw-match" <<'STUB'
#!/bin/bash
[[ -e $OMARCHY_TEST_VIVOBOOK && $1 == S5507QA ]]
STUB
# Stand-in for bsdtar: unzip the one member the checker asks for.
cat >"$test_tmp/bin/bsdtar" <<'STUB'
#!/bin/bash
archive="" dest="" member=""
while (($#)); do
  case $1 in
    -xf) archive=$2; shift 2 ;;
    -C) dest=$2; shift 2 ;;
    *) member=$1; shift ;;
  esac
done
python3 - "$archive" "$dest" "$member" <<'PY'
import sys
import zipfile
from pathlib import Path
archive, dest, member = sys.argv[1:]
wanted = member.replace("\\", "/")
with zipfile.ZipFile(archive) as zipped:
    names = {name.replace("\\", "/"): name for name in zipped.namelist()}
    if wanted not in names:
        sys.exit(1)
    target = Path(dest) / Path(wanted).name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(zipped.read(names[wanted]))
PY
STUB
chmod +x "$test_tmp/bin/omarchy-hw-match" "$test_tmp/bin/bsdtar"

export PATH="$test_tmp/bin:$PATH"
export OMARCHY_OEM_FIRMWARE_STATE="$test_tmp/state"
export OMARCHY_FIRMWARE_ROOT="$test_tmp/firmware"
export OMARCHY_TEST_VIVOBOOK="$test_tmp/vivobook"
unset OMARCHY_UPDATE_UNATTENDED OMARCHY_OEM_FIRMWARE_ASSUME_YES OMARCHY_OEM_FIRMWARE_ASSUME_NO
unset OMARCHY_IRIS_DT_FIRMWARE OMARCHY_ASUS_DRIVERS_URL

member='Driver/QualcommBSP/GFX/qcdx8380/qcvss8380_pa.mbn'

make_mbn() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import struct
import sys

dest, soc, life, cert = sys.argv[1:]
soc = int(soc, 0)
life = int(life)

def metadata():
    buf = bytearray(224)
    struct.pack_into("<I", buf, 0, 1)
    struct.pack_into("<I", buf, 16, soc)
    struct.pack_into("<I", buf, 148, life)
    return bytes(buf)

cert = cert.encode()
header = struct.pack("<10I", 0, 7, 24, 224, 224, 0, 0, len(cert), 0, 0)
common = struct.pack("<6I", 1, 0, 0, 0, 3, 0)
segment = header + common + metadata() + metadata() + cert
elf = bytearray(64)
elf[0:4] = b"\x7fELF"
elf[4] = 2
elf[5] = 1
elf[6] = 1
struct.pack_into("<HHIQQQIHHHHHH", elf, 16, 2, 183, 1, 0, 64, 0, 0, 64, 56, 1, 0, 0, 0)
phdr = struct.pack("<IIQQQQQQ", 0, 2 << 24, 120, 0, 0, len(segment), len(segment), 8)
open(dest, "wb").write(bytes(elf) + phdr + segment)
PY
}

make_package() {
  local mbn=$1 zip=$2
  python3 - "$mbn" "$zip" "$member" <<'PY'
import sys
import zipfile
mbn, dest, member = sys.argv[1:]
with zipfile.ZipFile(dest, "w") as zipped:
    zipped.write(mbn, member)
PY
}

publish() {
  local zip=$1 sha version=${2:-V1.319.8800.0}
  sha=$(sha256sum "$zip" | awk '{print $1}')
  python3 - "$test_tmp/drivers.json" "$zip" "$sha" "$version" <<'PY'
import json
import sys
dest, package, digest, version = sys.argv[1:]
json.dump({
    "Status": "SUCCESS",
    "Result": {
        "Obj": [{
            "Name": "Driver Package",
            "Files": [{
                "Title": "Qualcomm Board Support Package",
                "Version": version,
                "IsRelease": "1",
                "sha256": digest,
                "DownloadUrl": {"Global": "file://" + package},
            }],
        }, {
            "Name": "Networking",
            "Files": [{
                "Title": "Some other Qualcomm tool",
                "Version": "V9.9.9.9",
                "IsRelease": "1",
                "DownloadUrl": {"Global": "file:///does-not-exist"},
            }],
        }]
    },
}, open(dest, "w"))
PY
  export OMARCHY_ASUS_DRIVERS_URL="file://$test_tmp/drivers.json"
}

run_check() {
  "$cmd" check >"$test_tmp/out" 2>"$test_tmp/err"
}

touch "$OMARCHY_TEST_VIVOBOOK"
make_mbn "$test_tmp/good.mbn" 0xA016 2 production-oem-cert
"$cmd" verify "$test_tmp/good.mbn" 0xA016 >"$test_tmp/out"
grep -qx accept "$test_tmp/out" || fail "a production 0xA016 image is accepted" "$(cat "$test_tmp/out")"
make_mbn "$test_tmp/testroot.mbn" 0xA016 2 "General Use Test Key"
if "$cmd" verify "$test_tmp/testroot.mbn" >"$test_tmp/out" 2>"$test_tmp/err"; then
  fail "a test-root image is accepted"
fi
grep -qx 'reason=test-root' "$test_tmp/out" || fail "a test-root image is not named" "$(cat "$test_tmp/out")"
make_mbn "$test_tmp/dev.mbn" 0xA016 1 production-oem-cert
if "$cmd" verify "$test_tmp/dev.mbn" >"$test_tmp/out"; then
  fail "a development-signed image is accepted"
fi
grep -qx 'reason=development' "$test_tmp/out" || fail "a development image is not named" "$(cat "$test_tmp/out")"
make_mbn "$test_tmp/other.mbn" 0xA003 2 production-oem-cert
if "$cmd" verify "$test_tmp/other.mbn" 0xA016 >"$test_tmp/out"; then
  fail "an image for another SoC is accepted"
fi
grep -q 'reason=SoC' "$test_tmp/out" || fail "an image for another SoC is not named" "$(cat "$test_tmp/out")"
pass "MBN v7 checks accept only a production image for the X Plus SoC"

rm "$OMARCHY_TEST_VIVOBOOK"
cat >"$test_tmp/bin/curl" <<'STUB'
#!/bin/bash
echo "curl should not run" >&2
exit 99
STUB
chmod +x "$test_tmp/bin/curl"
run_check
[[ ! -e $test_tmp/state/vivobook-s5507qa.state ]] || fail "another machine records firmware state"
pass "other machines are left alone"

rm "$test_tmp/bin/curl"
touch "$OMARCHY_TEST_VIVOBOOK"
export OMARCHY_ASUS_DRIVERS_URL="file://$test_tmp/missing-drivers.json"
run_check
grep -q 'Could not reach ASUS' "$test_tmp/err" || fail "a network failure is not reported" "$(cat "$test_tmp/err")"
[[ ! -e $test_tmp/firmware/updates ]] || fail "a network failure installs firmware"
pass "a network failure is reported and does not stop the check"

make_package "$test_tmp/good.mbn" "$test_tmp/SOCPackage_good.zip"
publish "$test_tmp/SOCPackage_good.zip"
export OMARCHY_IRIS_DT_FIRMWARE="qcom/x1p42100/ASUSTeK/vivobook-s15/qcvss8380.mbn"
export OMARCHY_OEM_FIRMWARE_ASSUME_NO=1
run_check
[[ ! -e $test_tmp/firmware/updates ]] || fail "answering no installs the firmware"
if [[ -f $test_tmp/state/vivobook-s5507qa.state ]] && grep -q '^declined_version=V' "$test_tmp/state/vivobook-s5507qa.state"; then
  fail "an assumed no is recorded as a decline" "$(cat "$test_tmp/state/vivobook-s5507qa.state")"
fi
unset OMARCHY_OEM_FIRMWARE_ASSUME_NO
export OMARCHY_UPDATE_UNATTENDED=1
run_check
grep -q 'Skipped' "$test_tmp/out" || fail "an unattended update does not say it skipped" "$(cat "$test_tmp/out")"
[[ ! -e $test_tmp/firmware/updates ]] || fail "an unattended update installs the firmware"
if [[ -f $test_tmp/state/vivobook-s5507qa.state ]] && grep -q '^declined_version=V' "$test_tmp/state/vivobook-s5507qa.state"; then
  fail "an unattended skip is remembered as a decline"
fi
unset OMARCHY_UPDATE_UNATTENDED
pass "the offer defaults to no, including an unattended update"

export OMARCHY_OEM_FIRMWARE_ASSUME_YES=1
printf 'previous-firmware\n' >"$test_tmp/previous.mbn"
mkdir -p "$test_tmp/firmware/updates/qcom/x1p42100/ASUSTeK/vivobook-s15"
cp "$test_tmp/previous.mbn" "$test_tmp/firmware/updates/qcom/x1p42100/ASUSTeK/vivobook-s15/qcvss8380.mbn"
run_check
installed=$test_tmp/firmware/updates/qcom/x1p42100/ASUSTeK/vivobook-s15/qcvss8380.mbn
cmp -s "$test_tmp/good.mbn" "$installed" || fail "the DT filename gets the verified firmware"
grep -q '^installed_version=V1.319.8800.0$' "$test_tmp/state/vivobook-s5507qa.state" ||
  fail "the installed version is not recorded" "$(cat "$test_tmp/state/vivobook-s5507qa.state")"
cmp -s "$test_tmp/previous.mbn" "$test_tmp/state/vivobook-s5507qa.backup" ||
  fail "the previous firmware is not backed up"
grep -q 'Rollback: available' <("$cmd" status) || fail "status does not offer rollback" "$("$cmd" status)"
"$cmd" rollback >"$test_tmp/out"
cmp -s "$test_tmp/previous.mbn" "$installed" || fail "rollback does not restore the previous firmware"
grep -q 'Rollback: none' <("$cmd" status) || fail "status still offers rollback after it was used" "$("$cmd" status)"
pass "an accepted package installs under the device-tree name and rolls back"

export OMARCHY_IRIS_DT_FIRMWARE="qcom/x1p42100/ASUSTeK/vivobook-s15/qcvss8380_pa.mbn"
# The recorded version is empty after rollback, so the same package is offered again.
run_check
pa=$test_tmp/firmware/updates/qcom/x1p42100/ASUSTeK/vivobook-s15/qcvss8380_pa.mbn
cmp -s "$test_tmp/good.mbn" "$pa" || fail "a device tree that asks for qcvss8380_pa.mbn gets that filename"
pass "the install name follows qcvss8380_pa.mbn when the device tree asks for it"

publish "$test_tmp/SOCPackage_good.zip" V1.319.8800.0
run_check
grep -q 'already installed' "$test_tmp/out" || fail "the same version is offered again" "$(cat "$test_tmp/out")"
pass "a package that is not newer is not downloaded again"

python3 - <<PY
import pathlib
p = pathlib.Path("$test_tmp/drivers.json")
text = p.read_text().replace("$(sha256sum "$test_tmp/SOCPackage_good.zip" | awk '{print $1}')", "deadbeef")
p.write_text(text)
PY
# Force the checker to see this as newer than the installed V1.319.
sed -i 's/^installed_version=.*/installed_version=V1.0.0.0/' "$test_tmp/state/vivobook-s5507qa.state"
rm -f "$pa"
run_check
grep -q 'SHA-256' "$test_tmp/err" || fail "a bad download hash is not rejected" "$(cat "$test_tmp/err")"
[[ ! -e $pa ]] || fail "a bad download hash is installed"
pass "a download that does not match ASUS's SHA-256 is not installed"

make_mbn "$test_tmp/testroot.mbn" 0xA016 2 "General Use Test Key"
make_package "$test_tmp/testroot.mbn" "$test_tmp/SOCPackage_testroot.zip"
publish "$test_tmp/SOCPackage_testroot.zip" V2.0.0.0
run_check
grep -q 'test-root' "$test_tmp/err" || fail "a test-root package is not refused" "$(cat "$test_tmp/err")"
[[ ! -e $pa ]] || fail "a test-root package is installed"
pass "a test-root package is refused and nothing is installed"
