# Runbook

First stop when something on the estate misbehaves. Details per machine:
[machines.md](machines.md). Entry URLs: [repository table](../README.md#the-repositories).
Tables: [schema.md](schema.md).

> Production (`signcollect.nl`, host `cloud`) is read-only from this repo.
> The commands below are for the owner, or with the owner's OK.

## First 3 checks

1. [ ] [client_monitor_dashboard](https://signcollect.nl/client_monitor_dashboard/): which machine or job went quiet ([naming](machines.md#asking-the-estate-what-is-alive)).
2. [ ] `systemctl --failed` on the core server.
3. [ ] `df -h` on the core server. Full disk: [Disk full](#disk-full).

Then, as needed:

| Check | Command / place |
|---|---|
| Research-drive mount | `systemctl status rclone-mount.service` |
| One unit's log | `journalctl -u <unit> -n 200` |
| A pythonCron job's log / state | `/home/gomer/pythonCron/logs/<Job_Name>.log`, `state/<Job_Name>.json` |
| Timers | `systemctl list-timers 'vicon-*'` |
| Apache / PHP errors | `/var/log/apache2/error.log` |

A missing heartbeat means "nobody is listening", not "the job died". Check the unit first.

## Machine → service → unit

| Machine | Service (repo) | Unit / how it runs |
|---|---|---|
| core server | Every web component under `/web` | `apache2.service`, `php8.3-fpm.service` |
| core server | Database | `mysql.service` |
| core server | Research drive at `/web/gebarenoverleg_media/studioFiles` | `rclone-mount.service` |
| core server | Scheduler (pythonCron) | `python-scheduler.service` (`scheduler_v2.py`) |
| core server | Job wrappers (pythonCron) | `service-<job>.service` ×20, see below |
| core server | Wrapper watchdog, server monitor (pythonCron) | `watchdog-daemon.service`, `server-monitor.service` |
| core server | Vicon ingest (viconSync) | `vicon-ftp-monitor`, `vicon-glb-matcher`, `vicon-sync-rsync` `.service`; `vicon-blackmagic-mini.timer` (04:00), `vicon-cc-pipeline.timer` (hourly) |
| core server | Metrics (client_monitor_api) | `client-monitor-metrics.service` |
| core server | avatar.signcollect.nl (blendAnims, Vite on :5173) | `blendanims.service` |
| core server | FBX → GLB (no org repo) | `fbx2glb-server.service`, `fbx2glb-batch.service` |
| core server | Node servers (no repo) | `studio-support`, `unreal-server`, `llserver` `.service` |
| core server | mailChecker (no repo) | `studio-monitor`, `videos-monitor-dashboard`, `studio-dashboard` `.service` |
| core server | zin / annotation-tool nightly jobs | `crontab -l` of `gomer` (4 entries, [list](machines.md#5-crontab--l-for-gomer)) |
| Vicon PC | `bmcam serve` :8000 (blackmagic_control) | no unit; started by hand in a shell |
| Vicon PC | Pineapple adapter :8780 (blackmagic_control) | no unit; `blackmagic_pineapple_service/service.py` by hand |
| Vicon PC | Camera → research drive (blackmagic_RD_sync) | no unit; `python -m scripts.sync_clips` by hand |
| DRS | FX30 controller :8080 (Sony-SDK-MACOS-API) | no unit; `./Release/fx30MultiRecord --port 8080` by hand |
| DRS | Video pipeline (drs) | `startupScript.py` + `scripts/watchdog.sh` |
| monsterfish | HEVC encode target | nothing resident; reached over SSH by `vicon-blackmagic-mini` |
| demo hosts | Web, DB, scheduler | `apache2`, `php8.3-fpm`, `mysql`, `python-scheduler` `.service` (no wrappers) |

pythonCron wrapper units (`service-` + job name, lowercased; script from `services_config.json`):

| Unit | Runs |
|---|---|
| `service-get_themas` | `/web/zin/api/getThemas.php` |
| `service-clean_lock_files` | `/web/cleanLockFiles.php` |
| `service-converter` | `/web/helpScripts/convert.py` |
| `service-mysql_backup` | `/web/helpScripts/mysqlBackup.php` |
| `service-check_disk` | `pythonCron/checkDisk.py` |
| `service-copy_ab_files` | `/web/zin/copyAB.py` |
| `service-backup_zin_eaf_srt_files` | `/web/helpScripts/zinBackup.py` |
| `service-qrconvert` | `/web/qr/qrConvert.py` |
| `service-move_studiofiles` | `/web/helpScripts/check_studiofiles.py` |
| `service-check_if_raw_has_post_files` | `/web/tempScripts/compareFiles.py` |
| `service-convert_zinstring_to_lemmalist` | `/web/josBoard/lemma_lookup.py` |
| `service-update_field_glosses_at_sentences` | `/web/zin/eaf/zin/glosTosql.py` |
| `service-update_field_gvg_at_sentences` | `/web/zin/eaf/zin/GvGtoSql.py` |
| `service-match_records_for_livelink_videos_with_mocap_records` | `/web/mocap/matchRecords.py` |
| `service-match_vicon_fbx_csv_files_with_mocap_records` | `/web/mocap/matchVicon.py` |
| `service-convert_livelink_videos` | `/web/mocap/convert.py` |
| `service-rclone_mount_monitor` | `pythonCron/rclone_monitor.py` (production config only) |
| `service-sync_eaf_to_database` | `/web/zin/syncEafToDatabase.php` (production config only) |
| `service-sync_mocap_files` | `pythonCron/sync_mocap_files.py` (production config only) |
| `service-sync_vicon_files_rsync` | `viconSync/sync_vicon_rsync.py` (production config only; also run by `vicon-sync-rsync.service`) |

## Blast radius

| If this is down | What breaks | Who notices |
|---|---|---|
| `mysql` | Every page, API and job that reads the DB | Everyone, at once |
| `apache2` / `php8.3-fpm` | All of `signcollect.nl`, `api.signcollect.nl`, heartbeats to client_monitor_api | Everyone; dashboard shows all jobs offline |
| `rclone-mount` | Studio files for every job and page reading the research drive | Jobs log missing files; studio / video pages show gaps |
| `python-scheduler` + wrappers | Recordings stop being matched to sentences; lemma, gloss and EAF syncs stop; backups stop | Nobody until data looks stale; dashboard if the job heartbeats |
| `service-mysql_backup` | No new DB backups | Nobody |
| viconSync units | New Vicon captures do not reach the server / viconDashboard | Studio operator, in viconDashboard |
| `client-monitor-metrics` | Dashboard metrics go stale | Whoever opens the dashboard |
| `blendanims` | avatar.signcollect.nl | Avatar site users |
| Vicon PC | Skeleton capture, Blackmagic control and transcode | Studio operator |
| DRS | Multi-camera record (studio_beta loses cameras), render and crop | Studio operator |
| monsterfish | Nightly HEVC Mini copies only; sources stay on the core server | Nobody |
| A demo host | Demos only | Whoever is demoing |

## Restart

Order after a full outage: `mysql` → `rclone-mount` → `php8.3-fpm` → `apache2` → viconSync units → `python-scheduler` → wrappers → the rest.

| Service | Command |
|---|---|
| Web | `sudo apache2ctl configtest && sudo systemctl reload apache2` (restart only if reload fails) |
| PHP | `sudo systemctl restart php8.3-fpm` |
| MySQL | see [MySQL](#mysql) |
| Research drive | `sudo systemctl restart rclone-mount.service`; if "transport endpoint is not connected": `sudo fusermount -uz /web/gebarenoverleg_media/studioFiles` first |
| Scheduler | `sudo systemctl restart python-scheduler.service` (never delete `scheduler_state.db`: every job would run at once) |
| One job | `sudo systemctl restart service-<job>.service` |
| All wrappers | `sudo systemctl restart 'service-*.service'`, then `sudo systemctl restart watchdog-daemon.service` |
| viconSync | `sudo systemctl restart vicon-ftp-monitor vicon-glb-matcher vicon-sync-rsync` |
| Other core units | `sudo systemctl restart <unit>` |
| Vicon PC | in a shell: `.venv\Scripts\bmcam serve --bind 0.0.0.0 --port 8000` (blackmagic_control checkout) |
| DRS, cameras | in a shell: `./Release/fx30MultiRecord --port 8080 --download-path /tmp/fx30_downloads` |
| DRS, pipeline | `/usr/bin/python3 startupScript.py` (signlab_drs checkout) |
| Demo host | re-run the install; every step is idempotent ([install.md](install.md#if-it-stops-half-way)) |

### MySQL

- [ ] `systemctl status mysql`; `sudo tail -n 100 /var/log/mysql/error.log`
- [ ] Disk full? Fix [disk](#disk-full) first; MySQL will not start on a full disk.
- [ ] `sudo systemctl restart mysql`, then `sudo mysql -e 'SELECT 1'`
- [ ] Crash recovery loops in the log: stop, ask the owner. Do not delete `ib_logfile*` or anything in `/var/lib/mysql`.
- [ ] Restore: backups come from `service-mysql_backup` (`/web/helpScripts/mysqlBackup.php`, not in git). Backup location: TODO: owner.

### Apache

- [ ] `sudo apache2ctl configtest`: fix the named file and line before any restart.
- [ ] `sudo apache2ctl -S`: vhosts and the cert files they use.
- [ ] `sudo tail -n 100 /var/log/apache2/error.log`
- [ ] Only PHP pages fail: `sudo systemctl restart php8.3-fpm`.

### Certificate

- [ ] Expiry: `echo | openssl s_client -connect signcollect.nl:443 -servername signcollect.nl 2>/dev/null | openssl x509 -noout -enddate` (same for `api.` and `avatar.`)
- [ ] Production: renewal tool is not recorded in any repo. If certbot: `sudo certbot certificates`, `sudo certbot renew`, `sudo systemctl reload apache2`. TODO: owner to confirm.
- [ ] Demo hosts: `tailscale cert` into `/etc/ssl/demo/` (see `interface_deploy/scripts/provision.sh`), then reload Apache.

## Disk full

- [ ] `df -h` and `df -i` (inodes).
- [ ] Biggest: `sudo du -xh --max-depth=2 / 2>/dev/null | sort -h | tail -20`
- [ ] Usual suspects: `/home/gomer/pythonCron/logs` (50-100 MB per log), `/var/log`, `/var/lib/mysql`, `/web`.
- [ ] Logs: **truncate, never `rm`**. An open log keeps its space after `rm`. `: > /home/gomer/pythonCron/logs/<Job_Name>.log` or `sudo truncate -s 0 <file>`.
- [ ] Or `python3 /home/gomer/pythonCron/emergency_log_cleanup.py --log-dir /home/gomer/pythonCron/logs --dry-run`, then without `--dry-run`: keeps the last 50 MB of every log over 100 MB. Not scheduled ([#21](https://github.com/Amsterdam-Humanities-Labs/signlab_signcollect-stack/issues/21)); its default `--log-dir` is the pythonCron root, not `logs/`.
- [ ] journald: `sudo journalctl --vacuum-size=500M`
- [ ] Space still gone: `sudo lsof +L1` (deleted but open); restart that process.
- [ ] Never delete: `scheduler_state.db`, anything in `/var/lib/mysql`, anything under the research-drive mount.
- [ ] After: `systemctl --failed`; restart `mysql` first if it stopped.

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

## Escalation

| What | Who |
|---|---|
| Core server, DB, pythonCron, viconSync | TODO: owner |
| Studio machines (Vicon PC, DRS) | TODO: owner |
| Research drive (rclone remote) | TODO: owner |
| Domain / certificates | TODO: owner |
