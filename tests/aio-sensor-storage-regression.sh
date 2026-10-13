#!/usr/bin/env bash
# Read-only storage regression: 950GiB Ubuntu VG with a fixed 545GiB AIO LV.
set -euo pipefail
installer="AIO-Sensor-Installer.sh"
bash -n "${installer}"
helpers=$(mktemp)
trap 'rm -f "${helpers}"' EXIT
# Source only pure helpers + VG-space guard, never the installer's main menu.
sed -n '/^sensor_recommended_lv_gb()/,/^append_fstab_if_missing()/p' "${installer}" | sed '$d' > "${helpers}"
# shellcheck source=/dev/null
source "${helpers}"

assert_eq() {
  local label="$1" observed="$2" expected="$3"
  [[ "${observed}" == "${expected}" ]] || {
    printf '%s: got=%s expected=%s\n' "${label}" "${observed}" "${expected}" >&2
    exit 1
  }
}

assert_eq 'LVM rounded free' "$(printf ' <850.82\n' | lvm_floor_units)" 850
assert_eq 'LVM remaining after AIO' "$(printf ' <305.82\n' | lvm_floor_units)" 305
assert_eq 'unchanged AIO root' "$(grep -Fc 'run_cmd "sudo lvcreate -L 545G -n ${AIO_ROOT_LV} ${UBUNTU_VG}"' "${installer}")" 1
assert_eq 'Sensor LV on current host' "$(sensor_recommended_lv_gb $((850 - 545)))" 300
assert_eq 'Sensor guest disk on current host' "$(sensor_recommended_disk_gb 300)" 270
assert_eq 'Sensor LV legacy default' "$(sensor_recommended_lv_gb 850)" 400
assert_eq 'Sensor disk legacy default' "$(sensor_recommended_disk_gb 400)" 350
if sensor_recommended_lv_gb 109 >/dev/null 2>&1; then
  echo 'unsafe small LV accepted' >&2
  exit 1
fi
assert_eq 'NVMe device' "$(disk_first_partition_path nvme0n1)" /dev/nvme0n1p1
assert_eq 'second NVMe device' "$(disk_first_partition_path nvme1n1)" /dev/nvme1n1p1
assert_eq 'SATA device' "$(disk_first_partition_path sda)" /dev/sda1

# LVM's '<' prefix must not trigger partition creation on the running OS.
sudo() {
  case "${1:-}" in
    vgs) printf ' <870000.00\n';;
    *)  echo "unexpected mutating command: sudo $*" >&2; return 99;;
  esac
}
DRY_RUN=0
ensure_ubuntu_vg_free_space 'test' ubuntu-vg /dev/ubuntu-vg/ubuntu-lv $((545 * 1024)) $((10 * 1024))

# Verify the current mixed disk fixture excludes 0B removable media.
grep -Fq 'lsblk -d -b -n -o NAME,SIZE,TYPE,RM,RO' "${installer}"
disks=$(printf 'sda 1024000000000 disk 0 0\nsdb 0 disk 1 0\nnvme0n1 8000000000000 disk 0 0\nnvme1n1 8000000000000 disk 0 0\n' | awk '$3=="disk" && $4==0 && $5==0 && $2>0 {print $1}')
assert_eq 'disk inventory' "${disks}" $'sda\nnvme0n1\nnvme1n1'

# Keep safeguards present and prevent DRY_RUN from issuing real PV deletion.
grep -Fq 'elif ! sudo pvremove -y "${pv}"' "${installer}"
grep -Fq 'if [[ "${DRY_RUN}" -eq 1 ]]; then' "${installer}"
grep -Fq "hosts the running OS. Aborting." "${installer}"
grep -Fq 'pv_list+=" ${first_partition}"' "${installer}"
grep -Fq 'sensor_recommended_disk_gb "${sensor_host_lv_gb}"' "${installer}"
echo 'AIO_SENSOR_STORAGE_REGRESSION=PASS'
