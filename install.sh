#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
if (( EUID != 0 )); then echo 'Run: sudo ./install.sh --containers wordpress,mariadb,caddy [--enable-watchdog]' >&2; exit 1; fi
if [[ ! -d /run/systemd/system ]]; then echo 'systemd host required' >&2; exit 1; fi
python3 -c 'import tomllib; import sys; assert sys.version_info >= (3,11)' || { echo 'Python 3.11+ required' >&2; exit 1; }
command -v docker >/dev/null || { echo 'Docker CLI is required' >&2; exit 1; }
WATCHDOG=0
CONTAINERS=''
while (( $# )); do
  case "$1" in
    --containers) [[ $# -ge 2 ]] || exit 2; CONTAINERS="$2"; shift 2 ;;
    --enable-watchdog) WATCHDOG=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
if [[ -z "$CONTAINERS" && ! -f /etc/recoveryS/config.toml ]]; then
  echo 'Supply monitored names: --containers wordpress,mariadb,caddy' >&2; exit 2
fi
if [[ -n "$CONTAINERS" ]]; then
  export RECOVERYS_CONTAINERS="$CONTAINERS"
  python3 - <<'PY'
import os, sys
names=os.environ['RECOVERYS_CONTAINERS'].split(',')
if not all(n and n.strip()==n and not n.startswith('-') for n in names) or len(set(names))!=len(names):
    sys.exit('Invalid comma-separated container names')
PY
fi
install -d -m 755 /usr/local/lib/recoveryS /etc/recoveryS
install -d -m 700 /var/lib/recoveryS
install -d -m 750 /var/log/recoveryS
install -m 755 src/recoveryS.py /usr/local/lib/recoveryS/recoveryS.py
ln -sfn /usr/local/lib/recoveryS/recoveryS.py /usr/local/bin/recoveryS
if [[ ! -e /etc/recoveryS/config.toml ]]; then
  python3 - <<'PY'
import json, os
names=os.environ['RECOVERYS_CONTAINERS'].split(',')
with open('/etc/recoveryS/config.toml','w') as f:
    f.write('# Edit with: recoveryS -settings\n# Docker healthchecks are required for every named container.\n')
    f.write('containers = [' + ', '.join(json.dumps(n) for n in names) + ']\n')
    f.write('poll_seconds = 30\nconfirm_seconds = 60\nboot_grace_seconds = 120\n')
    f.write('restart_grace_seconds = 120\nhealthy_reset_seconds = 600\n')
    f.write('docker_command_timeout_seconds = 15\ndocker_restart_timeout_seconds = 90\n')
    f.write('enable_reboot = true\n')
PY
  chmod 640 /etc/recoveryS/config.toml
elif [[ -n "$CONTAINERS" ]]; then
  echo 'Existing config preserved. Edit container names with recoveryS -settings.'
fi
python3 - <<'PY'
import importlib.util, sys
path='/usr/local/lib/recoveryS/recoveryS.py'
spec=importlib.util.spec_from_file_location('recoverys', path)
app=importlib.util.module_from_spec(spec)
spec.loader.exec_module(app)
results=app.inspect(app.config())
print('Current Docker health:', results)
if any(v == 'missing' or v == 'no_healthcheck' or v == 'name_mismatch' or v == 'invalid_inspect' for v in results.values()):
    sys.exit('Fix container names and healthchecks before enabling recoveryS.')
PY
install -m 644 packaging/systemd/recoveryS.service /etc/systemd/system/recoveryS.service
install -m 644 packaging/logrotate/recoveryS /etc/logrotate.d/recoveryS
if (( WATCHDOG )); then
  if [[ ! -e /dev/watchdog && ! -e /dev/watchdog0 ]]; then
    echo 'No watchdog device is present; hardware watchdog was not enabled.' >&2
  else
    install -d -m 755 /etc/systemd/system.conf.d
    install -m 644 packaging/systemd/recoveryS-watchdog.conf /etc/systemd/system.conf.d/60-recoveryS-watchdog.conf
    echo 'Hardware watchdog configuration installed; takes effect at next boot.'
  fi
fi
systemctl daemon-reload
systemctl enable --now recoveryS.service
printf 'Installed. Check: recoveryS -status | recoveryS -check | recoveryS -log\n'
printf 'Edit: recoveryS -settings (or sudo recoveryS -settings)\n'
printf 'Only monitored containers with working Docker HEALTHCHECKs can arm recovery.\n'
