#!/bin/bash
# purpose: log system activity and alert when thresholds are exceeded (cron-safe)

# fail fast on unset vars; tolerate non-zero pipes (cron-friendly)
set -u

# minimal, explicit path (cron runs with a tiny environment)
PATH=/usr/sbin:/usr/bin:/bin
LC_ALL=C
umask 022

# user-writable log location (no sudo needed)
LOG_DIR="$HOME/.local/var/log"
LOG_FILE="$LOG_DIR/system_monitor.log"

# thresholds (%)
THRESHOLD_CPU=80
THRESHOLD_MEM=80
THRESHOLD_DISK=90

# ensure log dir exists
mkdir -p "$LOG_DIR" 2>/dev/null

# simple size-based rotation (~1 mb)
rotate_logs() {
  if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)" -gt 1048576 ]; then
    mv -f "$LOG_FILE" "$LOG_FILE.$(date +%Y%m%d%H%M%S)"
  fi
}

# get cpu usage percentage using /proc/stat delta
cpu_usage() {
  read -r _ u1 n1 s1 i1 w1 x1 y1 z1 a1 b1 < /proc/stat
  sleep 0.2
  read -r _ u2 n2 s2 i2 w2 x2 y2 z2 a2 b2 < /proc/stat

  total1=$((u1+n1+s1+i1+w1+x1+y1+z1+a1+b1))
  total2=$((u2+n2+s2+i2+w2+x2+y2+z2+a2+b2))
  idle=$((i2 - i1))
  total=$((total2 - total1))

  # avoid divide by zero
  if [ "$total" -le 0 ]; then
    echo "0.0"
    return
  fi

  # cpu busy% = (1 - idle/total) * 100
  awk -v idle="$idle" -v total="$total" 'BEGIN { printf "%.2f", (1 - (idle/total)) * 100 }'
}

# get memory usage percentage using /proc/meminfo (1 - available/total) * 100
mem_usage() {
  total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  avail_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
  if [ -z "$total_kb" ] || [ -z "$avail_kb" ] || [ "$total_kb" -eq 0 ]; then
    echo "0.0"
    return
  fi
  awk -v t="$total_kb" -v a="$avail_kb" 'BEGIN { printf "%.2f", (1 - (a/t)) * 100 }'
}

# get root fs disk usage percentage
disk_usage() {
  /bin/df -P / | /usr/bin/awk 'NR==2 {gsub(/%/,"",$5); printf "%.0f", $5}'
}

# float comparison helper: returns 0 (true) if a > b
float_gt() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a>b) }'
}

# log a line
log_line() {
  printf "%s | cpu: %s%% | mem: %s%% | disk: %s%%\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" "$3" >> "$LOG_FILE"
}

# log an alert
log_alert() {
  printf "%s | alert: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

# main
rotate_logs

CPU=$(cpu_usage)
MEM=$(mem_usage)
DISK=$(disk_usage)

log_line "$CPU" "$MEM" "$DISK"

# threshold checks (floats for cpu/mem, int for disk)
if float_gt "$CPU" "$THRESHOLD_CPU"; then
  log_alert "cpu usage above ${THRESHOLD_CPU}%%: ${CPU}%%"
fi

if float_gt "$MEM" "$THRESHOLD_MEM"; then
  log_alert "memory usage above ${THRESHOLD_MEM}%%: ${MEM}%%"
fi

if [ "$DISK" -gt "$THRESHOLD_DISK" ]; then
  log_alert "disk usage above ${THRESHOLD_DISK}%%: ${DISK}%%"
fi
