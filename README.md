# recoveryS

Docker health recovery for a Raspberry Pi 5 running Ubuntu Server.

The host service checks required containers, restarts Docker after a confirmed failure, and requests one orderly system reboot if recovery fails. A persistent latch prevents repeated recovery reboots. Timestamped logs record recovery actions.

## Install

Requires systemd, Docker Engine, Python 3.11+, and a Docker HEALTHCHECK for each monitored container. Use restart policies so containers return after Docker restarts.

After downloading and extracting this repository, open its folder on your Pi:

```bash
sudo bash install.sh --containers wordpress,mariadb,caddy
```

Replace the example names with your actual container names. Add `--enable-watchdog` to configure systemd's independent hardware watchdog, effective at the next boot when the device is available. The recovery service uses an orderly reboot; it does not deliberately expire the hardware watchdog.

## Commands

```bash
recoveryS -settings
recoveryS -status
recoveryS -check
recoveryS -log
recoveryS -log 200
```

Settings are stored in `/etc/recoveryS/config.toml` and reloaded during monitoring. See [full usage and recovery behavior](docs/USAGE.md), [example settings](config/config.example.toml), and [GitHub upload instructions](docs/GITHUB.md).

## Repository layout

| Path | Purpose |
| --- | --- |
| `src/` | Monitor and command interface |
| `tests/` | Simulated recovery tests |
| `config/` | Example configuration |
| `packaging/` | systemd units and log rotation |
| `install.sh`, `uninstall.sh` | Installation and removal |
| `docs/` | Setup, usage, and GitHub instructions |
| `.github/workflows/ci.yml` | Automated syntax and recovery checks |

## Development

No third-party Python packages are required.

```bash
python3 -m unittest discover -s tests -v
bash -n install.sh uninstall.sh
```

Tests mock Docker and reboot commands. They do not reboot the test machine. Actual Pi hardware behavior still requires testing on the target device.

## Uninstall

```bash
sudo bash uninstall.sh
```

Add `--purge` to delete retained configuration, logs, and state.

## License

No distribution license has been selected. The repository owner can add a LICENSE file before granting others reuse rights.
