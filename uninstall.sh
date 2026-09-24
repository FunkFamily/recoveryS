#!/usr/bin/env bash
set -euo pipefail
if (( EUID != 0 )); then echo 'Run: sudo ./uninstall.sh [--purge]' >&2; exit 1; fi
PURGE=0
if [[ "${1:-}" == --purge && $# -eq 1 ]]; then PURGE=1; elif (( $# )); then echo 'Unknown option' >&2; exit 2; fi
systemctl disable --now recoveryS.service 2>/dev/null || true
rm -f /etc/systemd/system/recoveryS.service /etc/logrotate.d/recoveryS /usr/local/bin/recoveryS /etc/systemd/system.conf.d/60-recoveryS-watchdog.conf
rm -rf /usr/local/lib/recoveryS
systemctl daemon-reload
if (( PURGE )); then rm -rf /etc/recoveryS /var/lib/recoveryS /var/log/recoveryS; fi
echo 'Removed. Config, logs, and state retained unless --purge was specified.'
echo 'If the hardware watchdog was enabled, its configuration removal takes effect at next boot.'
