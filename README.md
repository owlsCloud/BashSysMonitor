# Bash system monitor

**author:** javowl  
**description:** a lightweight bash script for logging system activity (cpu, memory, disk) and raising threshold alerts. designed to run via cron for continuous monitoring.

---

## Features

- logs **cpu, memory, and disk usage** with timestamps
- raises alerts when usage crosses configurable thresholds
- writes logs to `$HOME/.local/var/log/system_monitor.log` by default
- safe for cron (uses absolute paths + minimal env)
- simple log rotation to prevent runaway log growth

---

## Requirements

- linux system with bash (tested on ubuntu/debian)
- standard utilities: `top`, `free`, `df`, `awk`, `grep`, `stat`
- cron (or systemd timer)

---

## Installation

1. clone the repo:
   ```bash
   git clone https://github.com/<yourusername>/system-monitor.git
   cd system-monitor
   ```
