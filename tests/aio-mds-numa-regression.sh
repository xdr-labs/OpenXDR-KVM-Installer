#!/usr/bin/env bash
# Deterministic, read-only execution of the installer NUMA policy helpers.
set -euo pipefail
installer="AIO-Sensor-Installer.sh"
bash -n "${installer}"
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

sed -n '/^# BEGIN NUMA HELPERS$/,/^# END NUMA HELPERS$/p' "${installer}" |
  sed '1d;$d' > "${work}/helpers.sh"
[[ -s "${work}/helpers.sh" ]]
# shellcheck source=/dev/null
source "${work}/helpers.sh"

assert_eq() {
  [[ "$2" == "$3" ]] || {
    printf 'FAIL %s: got=%s expected=%s\n' "$1" "$2" "$3" >&2
    exit 1
  }
}

NUMA_SYSFS_ROOT="${work}/sys"
mkdir -p "${NUMA_SYSFS_ROOT}/node0" "${NUMA_SYSFS_ROOT}/node1"
printf 'Node 0 MemTotal: %s kB\n' $((128 * 1048576)) > "${NUMA_SYSFS_ROOT}/node0/meminfo"
printf 'Node 1 MemTotal: %s kB\n' $((128 * 1048576)) > "${NUMA_SYSFS_ROOT}/node1/meminfo"
printf '0-23,48-71\n' > "${NUMA_SYSFS_ROOT}/node0/cpulist"
printf '24-47,72-95\n' > "${NUMA_SYSFS_ROOT}/node1/cpulist"

{
  echo '# CPU,NODE,ONLINE'
  for ((i=0; i<96; i++)); do
    node=1
    if (( i < 24 || (i >= 48 && i < 72) )); then node=0; fi
    echo "${i},${node},Y"
  done
} > "${work}/topology.csv"

# All host and virsh interfaces are mocked. No VM or disk is touched.
lscpu() { cat "${work}/topology.csv"; }
log() { printf '%s\n' "$*" >> "${work}/numa.log"; }
virsh() {
  case "$1" in
    vcpucount)
      if [[ "$2" == aio ]]; then echo 48; else echo 44; fi ;;
    dominfo) echo 'Used memory: 83886080 KiB' ;;
    emulatorpin|vcpupin)
      echo "$*" >> "${work}/virsh.log"
      if [[ "$1" == vcpupin && "${FAIL_PIN_FOR_VCPU:-}" == "$3" ]]; then return 1; fi ;;
    numatune)
      if [[ "$3" == "--config" && "$#" -eq 3 ]]; then
        echo 'numa_mode : strict'
        if [[ "$2" == aio ]]; then echo 'numa_nodeset : 0'; else echo 'numa_nodeset : 1'; fi
      else
        echo "$*" >> "${work}/virsh.log"
      fi ;;
    *) echo "unexpected virsh call: $*" >&2; return 1 ;;
  esac
}

assert_eq 'expanded 0-23,48-71 range' "$(numa_cpu_count "$(numa_expand_cpu_list '0-23,48-71')")" 48
assert_eq 'NUMA node count' "$(numa_node_count)" 2
assert_eq 'NUMA0 CPUs' "$(numa_cpu_count "$(numa_node_cpu_list 0)")" 48
assert_eq 'NUMA1 CPUs' "$(numa_cpu_count "$(numa_node_cpu_list 1)")" 48
assert_eq 'MDS default CPU count' "$(numa_cpu_count "$(numa_take_cpus "$(numa_node_cpu_list 1)" 44)")" 44
# A saved legacy '1' MUST NOT replace the current NUMA-derived prompt default.
AIO_VCPUS=1
SENSOR_VCPUS=1
assert_eq 'AIO NUMA0 all 48 default' "$(numa_default_vm_vcpus "$(numa_node_cpu_list 0)" 0)" 48
assert_eq 'MDS NUMA1 48 minus 4 default' "$(numa_default_vm_vcpus "$(numa_node_cpu_list 1)" 4)" 44
assert_eq 'MDS NUMA1 24 minus 4 default' "$(numa_default_vm_vcpus "$(numa_expand_cpu_list '24-47')" 4)" 20
assert_eq 'MDS NUMA1 8 minus 4 default' "$(numa_default_vm_vcpus '0,1,2,3,4,5,6,7' 4)" 4
if numa_default_vm_vcpus '0,1,2,3' 4 >/dev/null 2>&1; then
  echo 'MDS default illegally leaves zero CPUs after host reserve' >&2
  exit 1
fi
assert_eq 'NUMA0 manual vCPU request' "$(numa_take_cpus "$(numa_node_cpu_list 0)" 8 | awk -F, '{print NF}')" 8
assert_eq 'NUMA1 manual vCPU request' "$(numa_take_cpus "$(numa_node_cpu_list 1)" 12 | awk -F, '{print NF}')" 12
numa_validate_guest_request aio 0 8 80
numa_validate_guest_request mds 1 12 80

# Verify actual Whiptail prompt arguments, not only helper arithmetic.
# Both fields start from current NUMA topology even if saved config was 1.
grep -Fq 'whiptail_inputbox "STEP 09 - AIO vCPU" "${aio_vcpu_msg}" "${default_aio_vcpus}"' "${installer}"
grep -Fq 'whiptail_inputbox "STEP 11 - Sensor (MDS) vCPU" "${vcpu_default_msg}" "${default_sensor_vcpus}"' "${installer}"
grep -Fq 'default_aio_vcpus=$(numa_default_vm_vcpus "${node0_cpus}" 0)' "${installer}"
grep -Fq 'default_sensor_vcpus=$(numa_default_vm_vcpus "${node1_cpus}" 4)' "${installer}"
grep -Fq 'AIO_VCPUS="${_AIO_VCPU_INPUT}"' "${installer}"
grep -Fq 'sensor_vcpus="${_SENSOR_VCPU_INPUT}"' "${installer}"

assert_eq 'node0 RAM safe cap' "$(numa_node_memory_limit_gib 0)" 108
assert_eq 'node1 RAM safe cap' "$(numa_node_memory_limit_gib 1)" 108
if numa_expand_cpu_list '5-3' >/dev/null 2>&1; then echo 'inverted CPU range accepted' >&2; exit 1; fi
if numa_validate_guest_request aio 0 49 80; then echo 'too many AIO CPUs accepted' >&2; exit 1; fi
if numa_validate_guest_request aio 0 48 109; then echo 'oversized AIO memory accepted' >&2; exit 1; fi

# A successful but empty ONLINE result must not pin CPUs from sysfs.
cp "${work}/topology.csv" "${work}/topology.good"
grep -vE '^[0-9]+,1,Y$' "${work}/topology.good" > "${work}/topology.csv"
if numa_node_cpu_list 1 >/dev/null 2>&1; then
  echo 'offline NUMA1 CPUs accepted from sysfs' >&2; exit 1
fi
mv "${work}/topology.good" "${work}/topology.csv"

# If lscpu fails completely, properly expand sysfs range lists.
lscpu() { return 1; }
assert_eq 'sysfs NUMA0 fallback' "$(numa_cpu_count "$(numa_node_cpu_list 0)")" 48
assert_eq 'sysfs NUMA1 fallback' "$(numa_cpu_count "$(numa_node_cpu_list 1)")" 48
lscpu() { cat "${work}/topology.csv"; }

DRY_RUN=0
numa_apply_vm_policy aio 0
numa_apply_vm_policy mds 1
assert_eq 'AIO vCPU pins' "$(grep -c '^vcpupin aio ' "${work}/virsh.log")" 48
assert_eq 'MDS vCPU pins' "$(grep -c '^vcpupin mds ' "${work}/virsh.log")" 44
assert_eq 'AIO first/last' "$(grep '^vcpupin aio 47 ' "${work}/virsh.log")" 'vcpupin aio 47 71 --config'
assert_eq 'MDS first/last' "$(grep '^vcpupin mds 43 ' "${work}/virsh.log")" 'vcpupin mds 43 91 --config'
assert_eq 'AIO memory' "$(grep '^numatune aio ' "${work}/virsh.log")" 'numatune aio --mode strict --nodeset 0 --config'
assert_eq 'MDS memory' "$(grep '^numatune mds ' "${work}/virsh.log")" 'numatune mds --mode strict --nodeset 1 --config'
numa_check_vm_memory_policy aio 0
numa_check_vm_memory_policy mds 1
if numa_check_vm_memory_policy mds 0; then echo 'incorrect NUMA nodeset accepted' >&2; exit 1; fi

: > "${work}/virsh.log"
DRY_RUN=1
numa_apply_vm_policy aio 0
[[ ! -s "${work}/virsh.log" ]] || { echo 'DRY_RUN modified VM' >&2; exit 1; }

DRY_RUN=0
FAIL_PIN_FOR_VCPU=3
if numa_apply_vm_policy aio 0; then echo 'failed vCPU pin was ignored' >&2; exit 1; fi
unset FAIL_PIN_FOR_VCPU
if grep -q '^numatune aio ' "${work}/virsh.log"; then
  echo 'partial pinning error proceeded to NUMA memory writes' >&2; exit 1
fi

# Regression contract: STEP 09/11 preflights and STEP 12 apply both nodes.
grep -Fq 'numa_validate_guest_request "aio" 0' "${installer}"
grep -Fq 'numa_validate_guest_request "mds" 1' "${installer}"
grep -Fq 'numa_apply_vm_policy "${SENSOR_VM}" 1' "${installer}"
grep -Fq 'numa_apply_vm_policy "${AIO_VM}" 0' "${installer}"
grep -Fq 'run_cmd "sudo lvcreate -L 545G -n ${AIO_ROOT_LV} ${UBUNTU_VG}"' "${installer}"
echo 'AIO_MDS_NUMA_REGRESSION=PASS'
