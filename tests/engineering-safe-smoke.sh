#!/usr/bin/env bash
set -euo pipefail
installers=(6000-Sensor-Installer.sh AIO-Sensor-Installer.sh DP-Installer.sh Sensor-Installer.sh)
bash -n "${installers[@]}"
for f in "${installers[@]}"; do
  grep -q 'DRY_RUN' "$f" || { echo "missing DRY_RUN contract: $f" >&2; exit 1; }
  grep -q 'pipefail' "$f" || { echo "missing strict shell mode: $f" >&2; exit 1; }
done
echo "ENGINEERING_SAFE_SMOKE=PASS"
