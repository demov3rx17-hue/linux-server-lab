#!/usr/bin/env bash
# Writes a compact YAML-like health report to stdout; systemd captures it in journald.
set -Eeuo pipefail

CPU_WARN_PERCENT="${CPU_WARN_PERCENT:-90}"
RAM_WARN_PERCENT="${RAM_WARN_PERCENT:-90}"
DISK_WARN_PERCENT="${DISK_WARN_PERCENT:-85}"

status_for_service() {
  systemctl is-active --quiet "$1" && printf 'OK' || printf 'CRITICAL'
}

cpu_usage="$(LC_ALL=C top -bn1 | awk -F ',' '/Cpu\(s\)/ {for (i = 1; i <= NF; i++) if ($i ~ / id/) {gsub(/[^0-9.]/, "", $i); print int(100 - $i); exit}}')"
ram_usage="$(free | awk '/Mem:/ {print int(($3 / $2) * 100)}')"
disk_usage="$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')"

cpu_status=OK; (( cpu_usage >= CPU_WARN_PERCENT )) && cpu_status=WARNING
ram_status=OK; (( ram_usage >= RAM_WARN_PERCENT )) && ram_status=WARNING
disk_status=OK; (( disk_usage >= DISK_WARN_PERCENT )) && disk_status=WARNING

printf 'CPU: %s\n' "$cpu_status"
printf 'RAM: %s\n' "$ram_status"
printf 'DISK: %s\n' "$disk_status"
printf 'NGINX: %s\n' "$(status_for_service nginx)"
printf 'SSH: %s\n' "$(status_for_service ssh)"
printf 'DOCKER: %s\n' "$(status_for_service docker)"
printf 'METRICS: cpu=%s%% ram=%s%% disk=%s%%\n' "$cpu_usage" "$ram_usage" "$disk_usage"
