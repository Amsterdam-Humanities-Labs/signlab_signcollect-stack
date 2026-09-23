# Production: the core server

How the core server (`signcollect.nl`, host `cloud`, user `gomer`) is laid out,
and how a change reaches it today. The demo hosts are in [install.md](install.md)
and [deploy.md](deploy.md). Unit names and restarts are in [machines.md](machines.md)
and the [runbook](runbook.md).

> Production is updated by hand, by the owner. The install toolchain in
> `interface_deploy/` is for demo hosts only: never run it against production.
> Anything marked "TODO: confirm" was not verifiable from the repositories.

## What runs where

### Web components: `/web/<dir>`, served by Apache

Each directory is a git checkout of one repo. Apache, PHP-FPM and MySQL serve them.
`repos.tsv` records the branch production has checked out.

| `/web/<dir>` | Repo | Branch |
|---|---|---|
| `lib` | signlab_signcollect-lib | main |
| `menu_beta` | signlab_signCollect-v2 | main |
| `zin` | signlab_zin | main |
| `zin/api` | signlab_sCAPI (also `api.signcollect.nl`) | main |
| `videoFix`, `studioIndex`, `studio_beta` | signlab_videoFix, _studioIndex, _studio_beta | main |
| `hh` | signlab_hh | **master** |
| `annotation-tool`, `annotation-editors` | signlab_annotation-tool, _annotation-editors | main |
| `animMIDI` | signlab_sC-Animation-PP | main |
| `mocap_site` (vhost `mocap.signcollect.nl`), `mocap`, `mocapStudio`, `viconDashboard` | the repo of the same name | main |
| `blendBaking` | signlab_blendAnims | main |
| `videoBackgroundFix`, `mocapDataPackage`, `s3b_glb`, `s3b_server`, `s3b_viewer`, `mhr`, `client_monitor_api`, `client_monitor_dashboard` | the repo of the same name | TODO: confirm |

- `/web/mocap_lab`: `signlab_mocap_lab` was merged into `signlab_mocapStudio` as `lab/` ([#37](https://github.com/Amsterdam-Humanities-Labs/signlab_signcollect-stack/issues/37)). Demo hosts symlink `/web/mocap_lab` to `/web/mocapStudio/lab`. TODO: confirm whether production still has a separate `mocap_lab` checkout, and when to switch it.
- `/web/gebarenoverleg_media/studioFiles` is the research drive, mounted by `rclone-mount.service`. Not a repo.
- Copied into a repo on 2026-09-22 but not deployed from it ([#35](https://github.com/Amsterdam-Humanities-Labs/signlab_signcollect-stack/issues/35)): `/web/helpScripts` (signlab_helpScripts), `/web/qr` (signlab_qr; `qrConvert.py` is missing from it), `/web/josBoard` (signlab_josBoard). pythonCron runs files from all three. `/web/jari/BabylonSignLab` is forked as signlab_BabylonSignLab, also not deployed from it.
- Production vhosts (`signcollect.nl`, `api.`, `mocap.`, `avatar.`) are not in this repo. The files in `interface_deploy/apache/` are demo templates. TODO: confirm the production vhost files and certificate renewal.

### Services outside `/web`

| Path | Repo | Units |
|---|---|---|
| `/home/gomer/pythonCron` | signlab_pythonCron (remote still `rem0g/pythonCron`) | `python-scheduler`, `watchdog-daemon`, `server-monitor`, `service-<job>` ×20 |
| `/home/gomer/viconSync` | signlab_viconSync (remote still `rem0g/viconSync`) | `vicon-ftp-monitor`, `vicon-glb-matcher`, `vicon-sync-rsync`; `vicon-blackmagic-mini.timer`, `vicon-cc-pipeline.timer` |
| `/home/gomer/node_servers/blendAnims` | personal `rem0g/blendAnims` | `blendanims` (Vite behind `avatar.signcollect.nl`) |
| `/home/gomer/node_servers/{fbx2glb,studioSupport,unrealServer,llServer}`, `/home/gomer/mailChecker` | none in the org | see [machines.md](machines.md#4-storage-monitoring-and-the-node-services) |
| `/opt` | — | TODO: confirm what, if anything, production keeps in `/opt`. Demo hosts use `/opt/pythonCron`; production does not. |

Cron (`crontab -l` of `gomer`): four entries in `zin` and `annotation-tool`, listed in
[machines.md](machines.md#5-crontab--l-for-gomer).

### Configuration files (not in git)

| File | Read by |
|---|---|
| `/web/.env` | signcollect-lib (`sc_env()`, `sc_db_config()`): DB settings and the upload tokens |
| `/web/zin/.env` | pythonCron (`move_studiofiles.py`, `server_monitor.py`): `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` |
| `mysql_config.php` (per component, and `/web/mysql_config.php`) | older PHP code |
| `/home/gomer/viconSync/monitor_config.json` | viconSync (`ftp.password` or `VICON_PASSWORD`) |

## How a component is updated today

1. [ ] Run the [pre-update checklist](#pre-update-checklist).
2. [ ] `cd /web/<dir> && git pull` (branch from the table above).
3. [ ] PHP and static files take effect at once. Reload Apache only if its config changed.
4. [ ] For pythonCron and viconSync, restart the units (see [runbook](runbook.md#restart)).

**Once only, for the 7 repos whose history was rewritten on 2026-09-22**
([#20](https://github.com/Amsterdam-Humanities-Labs/signlab_signcollect-stack/issues/20)):
`git pull` fails or makes a merge mess. After a backup, run instead:

```bash
git fetch && git reset --hard origin/<branch>
```

| Repo | On the core server |
|---|---|
| signlab_zin | `/web/zin` |
| signlab_hh | `/web/hh` (branch `master`) |
| signlab_annotation-tool | `/web/annotation-tool` |
| signlab_sC-Animation-PP | `/web/animMIDI` |
| signlab_videoBackgroundFix | `/web/videoBackgroundFix` |
| signlab_s3b_server | `/web/s3b_server` |
| signlab_Sony-SDK-MACOS-API | not here (DRS) |

`reset --hard` throws away uncommitted changes. That is why `git status` comes first.

## Pending switch-overs

Merged in the repos, not yet applied on production. Apply each group together.

| What | Steps |
|---|---|
| pythonCron ([#33](https://github.com/Amsterdam-Humanities-Labs/signlab_signcollect-stack/issues/33)) | Follow the checklist in [signlab_pythonCron#6](https://github.com/Amsterdam-Humanities-Labs/signlab_pythonCron/pull/6): back up the checkout and the units, repoint `origin` to the org repo, check out `main`, reinstall units, `daemon-reload`, disable `service-update_field_glosses_at_sentences`, restart. |
| viconSync ([#33](https://github.com/Amsterdam-Humanities-Labs/signlab_signcollect-stack/issues/33)) | Follow [signlab_viconSync#5](https://github.com/Amsterdam-Humanities-Labs/signlab_viconSync/pull/5): back up, add the org remote, `git checkout -f -B main org/main` (no shared history), reinstall `vicon-*` units, restart timers. Do this together with pythonCron: it schedules `sync_vicon_rsync.py`. |
| `DB_PASSWORD` | Must be in `/web/zin/.env` before the pythonCron switch-over. `move_studiofiles.py` no longer carries it. |
| Upload tokens ([#31](https://github.com/Amsterdam-Humanities-Labs/signlab_signcollect-stack/issues/31)) | Before pulling `mocap`, `mocapDataPackage` or `s3b_server`: set `SC_UPLOAD_TOKEN` and `S3B_WORKER_TOKEN` in `/web/.env` (or Apache `SetEnv`). Unset means every upload is refused. Give the capture curl, the OBS uploader and the s3b GPU worker the `X-Api-Token` header; their code is in no repo. |
| `BMCAM_API_KEY` ([#31](https://github.com/Amsterdam-Humanities-Labs/signlab_signcollect-stack/issues/31)) | On the Vicon PC, not the core server: `bmcam serve` now needs it (or `--no-auth`). blackmagic_RD_sync sends the same variable. |
| annotation-tool data | Cluster review data moved out of the checkout. Before pulling, copy `status.json`, `merge_decisions.json` and `eaf/` from `/web/annotation-tool/clusters/edit/` to `/web/annotation_data/clusters/` (writable by `www-data`). The pull deletes the old copies, and missing files are seeded from `clusters/edit/seed/`, so skipping this loses production's review work. Deny the new directory in Apache (`Require all denied`), as the demo template does. |
| Editors' EAFs | subBeta8 and 3DAnn3 now save through zin to `/web/zin/eaf/zin/`. Before pulling `annotation-editors`, move any EAFs from `/web/annotation-editors/{subBeta8,3DAnn3}/zin/eaf/zin/` to `/web/zin/eaf/zin/`. TODO: confirm which EAFs exist there. |

## Pre-update checklist

- [ ] Tell the owner. Production is not changed without them.
- [ ] `git status` in every checkout you will touch. Local changes: commit and push them, or stop and ask.
- [ ] `git remote -v`: the remote must be the org repo, not `rem0g/*`.
- [ ] Back up the directory, including untracked files: `tar czf ~/backup-<dir>-$(date +%F).tgz -C /web <dir>`.
- [ ] Database dump: `mysqldump --single-transaction <db> > ~/db-$(date +%F).sql`. The database is `admin_gebarenoverleg`. `service-mysql_backup` writes per-table dumps to `/web/gebarenoverleg_media/studioFiles/sqlBackups/` (from the code; TODO: confirm on the server).
- [ ] For pythonCron and viconSync, also back up `/etc/systemd/system/` units, `logs/`, `state/`, `*.db` and `*_state.json`. Never delete `scheduler_state.db`.
- [ ] Check disk space first: `df -h`.
- [ ] Afterwards: open the component's entry page, `systemctl --failed`, `tail /var/log/apache2/error.log`.

## Rebuilding the core server

There is no procedure. TODO: confirm with the owner. The pieces above (repo table,
units, config files, cron) are the inventory a rebuild would need.
