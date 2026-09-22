# Runbook

First stop when something on the estate misbehaves. Unit names and hosts are in
[machines.md](machines.md); entry URLs are in the
[repository table](../README.md#the-repositories). Production is read-only
from here: check, then ask the owner before restarting anything.

## Check first

| Check | Command / place |
|---|---|
| Which machines and jobs still report | [client_monitor_dashboard](https://signcollect.nl/client_monitor_dashboard/), see [machines.md](machines.md#asking-the-estate-what-is-alive) |
| Failed units on the core server | `systemctl --failed` |
| Disk | `df -h` |
| Research-drive mount | `systemctl status rclone-mount.service` |
| One unit's log | `journalctl -u <unit> -n 200` |
| A pythonCron job's log | `/home/gomer/pythonCron/logs/<Job_Name>.log` |

A missing heartbeat means "nobody is listening", not "the job died". Check the
unit before concluding anything.

## Known symptoms

| Symptom | Cause / fix |
|---|---|
| A page returns 500 | Usually a directory with no index file. Open the entry point from the repo table, not the bare folder. |
| A script cannot reach the database | Check the credentials file exists and is readable by the process: `/web/.env` via `signcollect-lib`, or the component's `mysql_config.php`. PHP runs as `www-data`; a mode-600 file owned by someone else is unreadable to it. |
| Every `bmcam` call 404s | Web Media Manager and the REST API are not enabled in the Blackmagic camera's settings. |
| Vicon sync stopped after a Windows reinstall | The Vicon PC's tailnet address changed. `vicon_host.py` should rediscover it from `tailscale status`. |
| A capture is stuck yellow in viconDashboard | All five subdirectories arrived but files are still growing: the upload has not finished. Red means a required subdirectory is really missing. |
| A file is on the recording machine but not on the web | Not every subdirectory is synced. Livelink CSV, metadata JSON, `unreal/CC`, `unreal/Vicon` and shogun_post files stay on Windows by design. |
| Jobs report missing studio files | `rclone-mount.service` dropped. Almost everything downstream reads through that mount. |
| FX30 cameras do not record | `fx30MultiRecord` on DRS has no supervisor. Someone starts it by hand (see [machines.md](machines.md#drs)). |

## Blast radius

| Down | Lost |
|---|---|
| Apache / PHP-FPM / MySQL on the core server | Every web component, the API and the database |
| `rclone-mount.service` | Studio files for every job that reads the research drive |
| Vicon PC | Skeleton capture, Blackmagic control and transcode |
| DRS | Multi-camera record, render and crop pipeline |
| monsterfish | The nightly HEVC encode only; sources stay on the core server |
| A demo host | Demos only; production is unaffected |

## Demo hosts

Re-run the install; every step is idempotent. See
[install.md](install.md#if-it-stops-half-way).
