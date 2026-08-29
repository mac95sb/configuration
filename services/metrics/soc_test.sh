#!/bin/sh
set -eu

output=$(mktemp "${TMPDIR:-/tmp}/soc-metrics.XXXXXX")
trap 'rm -f "$output"' EXIT HUP INT TERM
METRICS_FILE=$output "$(dirname "$0")/soc.sh"

for metric in host_gpu_utilization_ratio host_gpu_memory_bytes host_ane_busy_seconds_total host_power_watts host_battery_charge_ratio host_memory_pressure_ratio; do
	grep -Eq "^$metric [0-9]+([.][0-9]+)?$" "$output"
done
