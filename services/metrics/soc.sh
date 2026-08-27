#!/bin/sh
set -eu

output=${METRICS_FILE:-/Users/svc_observability/textfile/soc.prom}
gpu=$(/usr/sbin/ioreg -r -c IOAccelerator -d 1 -l)
gpu_util=$(printf '%s\n' "$gpu" | sed -n 's/.*"Device Utilization %"=\([0-9][0-9]*\).*/\1/p' | head -1)
gpu_memory=$(printf '%s\n' "$gpu" | sed -n 's/.*"In use system memory"=\([0-9][0-9]*\).*/\1/p' | head -1)
ane_busy_ms=$(/usr/sbin/ioreg -r -n ane0 -d 0 | sed -n 's/.*busy [0-9][0-9]* (\([0-9][0-9]*\) ms).*/\1/p' | head -1)
power_mw=$(/usr/sbin/ioreg -r -c AppleSmartBattery -d 0 -l | sed -n 's/.*"SystemLoad"=\([0-9][0-9]*\).*/\1/p' | head -1)

for value in "$gpu_util" "$gpu_memory" "$ane_busy_ms" "$power_mw"; do
  case $value in '' | *[!0-9]*)
    printf 'unexpected I/O Registry metric: %s\n' "$value" >&2
    exit 1
    ;;
  esac
done

tmp=$output.tmp
cat >"$tmp" <<EOF
# HELP host_gpu_utilization_ratio Current GPU device utilization.
# TYPE host_gpu_utilization_ratio gauge
host_gpu_utilization_ratio $(awk -v value="$gpu_util" 'BEGIN { print value / 100 }')
# HELP host_gpu_memory_bytes Unified memory currently attributed to the GPU.
# TYPE host_gpu_memory_bytes gauge
host_gpu_memory_bytes $gpu_memory
# HELP host_ane_busy_seconds_total Cumulative ANE driver busy time.
# TYPE host_ane_busy_seconds_total counter
host_ane_busy_seconds_total $(awk -v value="$ane_busy_ms" 'BEGIN { print value / 1000 }')
# HELP host_power_watts Current estimated system power consumption.
# TYPE host_power_watts gauge
host_power_watts $(awk -v value="$power_mw" 'BEGIN { print value / 1000 }')
EOF
mv "$tmp" "$output"
