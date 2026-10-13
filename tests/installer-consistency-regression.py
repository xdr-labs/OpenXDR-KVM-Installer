#!/usr/bin/env python3
"""Offline regression checks; never source installer entrypoints or change the host."""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = ("DP-Installer.sh", "AIO-Sensor-Installer.sh", "Sensor-Installer.sh")
contents = ${name: (ROOT / name).read_text() for name in FILES}

def fn(source, name):
    m = re.search(r"(?m)^" + re.escape(name) + r"\(\) \{$", source)
    assert m, f"function not found: ${name}"
    end = source.find("\n}\n", m.start())
    assert end >= 0, f"unterminated function: ${name}"
    return source[m.start():end + 3]

def bash(source):
    p = subprocess.run(["bash", "-c", "set -euo pipefail\n" + source],
                       capture_output=True, text=True, timeout=10)
    assert p.returncode == 0, f"Bash error: ${p.stderr}; output=${p.stdout}"

for filename, source in contents.items():
    subprocess.run(["bash", "-n", str(ROOT / filename)], check=True, timeout=10)
    assert "set -euo pipefail" in source
    assert "installer_vm_budget_check()" in source
    mock_host = """
log() { :; }
getconf() { echo 96; }
awk() { if [[ "$*" == *'/proc/meminfo'* ]]; then echo 256; else command awk "$@"; fi; }
"""
    bash(mock_host + fn(source, "installer_vm_budget_check") + """
installer_vm_budget_check test 42 136 46 80
! installer_vm_budget_check test 48 150 48 80
! installer_vm_budget_check test 42 136 46 100
! installer_vm_budget_check test 0 8
! installer_vm_budget_check test '1; touch /tmp/bad' 4
! installer_vm_budget_check test 08 4
""")
    print("PASS", filename, "syntax, host resource budget and bad-input rejection")

dp = contents["DP-Installer.sh"]
aio = contents["AIO-Sensor-Installer.sh"]
sensor = contents["Sensor-Installer.sh"]

bash(fn(dp, "installer_partition_one") + """
[[ $(installer_partition_one sda) == /dev/sda1 ]]
[[ $(installer_partition_one nvme0n1) == /dev/nvme0n1p1 ]]
[[ $(installer_partition_one mmcblk0) == /dev/mmcblk0p1 ]]
! installer_partition_one 'bad;name'
""")
assert "installer_verify_data_disk" in dp
assert "Refusing to wipe OS or swap disk" in dp
assert "Root filesystem is not on a detectable LVM VG" in dp
print("PASS DP storage: NVMe naming, disk identity and LVM fail-closed")

assert "disk_first_partition_path()" in aio
assert 'elif ! sudo pvremove -y "${pv}"' in aio
assert "[DRY-RUN] VG expansion simulated" in aio
assert "numa_default_vm_vcpus" in aio
assert "numa_validate_guest_request" in aio
assert "Existing AIO VM is present" in aio
assert aio.index("This operation is IRREVERSIBLE.") < aio.index("If an existing AIO VM is present")
print("PASS AIO: retains current NUMA policy, safe PV removal and VM cleanup ordering")

assert "-o vg_free" in sensor
assert "STEP 07] Existing Sensor VM preserved" in sensor
assert "installer_download_validated()" in sensor
assert "installer_same_device()" in sensor
assert "validate_sensor_qcow2_candidate" in sensor
assert "Sensor VM disk" in sensor
assert "return 2" in sensor
assert "dpkg-query -W" in sensor
assert "Root filesystem is not on an identifiable LVM VG" in sensor
print("PASS Sensor: real VG free extents, image source, mount identity and cancel state")

with tempfile.TemporaryDirectory() as td:
    valid = Path(td) / "aella-modular-ds-6.5.0.qcow2"
    invalid = Path(td) / "aella-dataprocessor-6.5.0.qcow2"
    valid.write_bytes(b"QFI\xfb" + bytes(2 * 1024 * 1024))
    invalid.write_bytes(valid.read_bytes())
    mock = """
qemu-img() { printf 'image: mock\\nfile format: qcow2\\nvirtual size: 350 GiB\\n'; }
"""
    bash(mock + fn(sensor, "validate_qcow2_image") +
         fn(sensor, "validate_sensor_qcow2_candidate") +
         f"""
validate_sensor_qcow2_candidate '{valid}' 6.5.0
! validate_sensor_qcow2_candidate '{invalid}' 6.5.0
! validate_sensor_qcow2_candidate '{valid}' 6.4.9
""")
print("INSTALLER_CONSISTENCY_REGRESSION=PASS")
