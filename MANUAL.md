# SignCollect / Zin — Operations Manual

Every repository in the platform, in the order data flows through it: what each
one is for, why it exists, how to use its interface, and what it depends on.

The [README](README.md) is the index and the architecture diagram. This is the
manual you read when you actually have to *use* or *run* something.

---

## Before you start

**Everything lives in one organisation.** All 27 repos are under
[Amsterdam-Humanities-Labs](https://github.com/orgs/Amsterdam-Humanities-Labs/repositories?q=signlab_)
with a `signlab_` prefix. Every organisation member already has access — there
is nothing to request.

**Deployment is by convention.** A repo named `signlab_<name>` is deployed to
`/web/<name>` on the production host and served at
`https://signcollect.nl/<name>/`. The exceptions are noted in each entry.

**One database.** Almost everything reads or writes the MySQL database
`admin_gebarenoverleg` on the production host. The important tables:

| Table | Holds |
|---|---|
| `form_data` | Glosses — the core vocabulary records |
| `sentences` | Sentence text (`zinString`) used across the annotation tools |
| `vicon_captures` | Mocap capture sessions (date, recording dir, file counts) |
| `vicon_files` | Individual capture files, their subdirectory and status |
| `matched_transcriptions` | Links recordings to sentences (`m_file`, `m_transcription`) |

**Credentials are never in git.** Each repo that needs the database reads a
gitignored `db_credentials.py`, `db_credentials.php`, or `mysql_config.php`,
with a committed `*.example.*` template beside it. Deploying to a new host means
copying the example and filling in the password. If a script suddenly cannot
connect, this file is the first thing to check.

**Live links.** Every URL below returns HTTP 200 unless marked otherwise.
Several directories have no index page and will return a 500 if you open the
bare folder — always use the specific entry point given here.

---

# Part 1 — Capture

Getting recordings off the cameras and the mocap rig.

## signlab_Sony-SDK-MACOS-API

**Repo:** [signlab_Sony-SDK-MACOS-API](https://github.com/Amsterdam-Humanities-Labs/signlab_Sony-SDK-MACOS-API) · **the one public repo** · C++
**Runs on:** an operator's macOS machine, not the server — `http://localhost:8080`

Drives several Sony FX30 cameras over USB from macOS: synchronised record
start/stop, property monitoring, media formatting, file download and settings
presets. Built on the Sony Camera Remote SDK.

It exists because the FX30s have no usable network control — the only way to
start five cameras at the same instant is a local process holding all the USB
connections.

**Using it.** Start the process, then open the embedded dashboard:

```bash
cd simpleCli/build/Mac
./fx30MultiRecord --port 8080 --download-path /tmp/fx30_downloads
```

Open `http://localhost:8080/` for the built-in HTML dashboard, or drive the
JSON API under `/api/*`. Rules that will bite you if you skip them:

- `GET /api/status` is the single source of truth — poll it every 1–2 s. There
  are no websockets.
- HTTP status is **always 200**. Errors come back as an `"error"` key in the
  JSON body. Always check for it.
- Long operations (`/api/scan`, `/api/reset`, `/api/download`, `/api/list-files`)
  return immediately and report progress through `/api/status`.
- Commands are **broadcast to all cameras** — there is no per-camera addressing.
  Responses are aggregate counts like `{"ok":5,"failed":0}`.
- Every POST needs a JSON body. Send at least `{}` with
  `Content-Type: application/json`, or you get an empty HTTP 400.
- No authentication and no CORS headers — serve your UI from the same origin or
  proxy it.

Full detail is in the repo's `AGENT_API_GUIDE.md`.

## signlab_blackmagic_control

**Repo:** [signlab_blackmagic_control](https://github.com/Amsterdam-Humanities-Labs/signlab_blackmagic_control) · Python
**Runs on:** the capture machine, as the `bmcam` REST server

CLI and Python library for a Blackmagic camera's Camera Control REST API (a 6K
Pro by default): recording start/stop, video format, media listing, clip
download.

**The one-time setup that trips everyone up:** the camera serves port 80 but
returns 404 for everything until **Web Media Manager** *and* **REST API** are
switched on in the camera's own settings. If every call 404s, that is why.

`blackmagic_RD_sync` is a client of this server, so this has to be running
before the sync cycle will do anything.

## signlab_blackmagic_RD_sync

**Repo:** [signlab_blackmagic_RD_sync](https://github.com/Amsterdam-Humanities-Labs/signlab_blackmagic_RD_sync) · Python

An autonomous cycle that clears every `.braw` off the camera's USB disk:
download through the `bmcam` server → transcode to H.265 (Blackmagic RAW SDK
piped into ffmpeg's `hevc_videotoolbox`) → upload to the research drive →
verify → delete the source from the camera.

Two details that matter more than they look:

- The clip's **start timecode** is carried into the MP4 as a SMPTE `tmcd` track,
  so editorial sync survives the transcode.
- Verification checks the file is **durable upstream**, not merely sitting in
  the rclone VFS write-back cache, before anything is deleted.

Undecodable clips are archived as the original `.braw` rather than dropped. The
pipeline is idempotent and resume-aware, so re-running after a failure is safe.

## signlab_viconSync

**Repo:** [signlab_viconSync](https://github.com/Amsterdam-Humanities-Labs/signlab_viconSync) · Python

Pulls motion-capture output off the Vicon PC into storage and the database.

The Vicon PC rejoins the tailnet on a new address after every Windows
reinstall, so nothing is pinned: `vicon_host.py` discovers it at runtime from
`tailscale status`. If sync breaks after a machine rebuild, that discovery step
is where to look.

| Script | Does |
|---|---|
| `sync_vicon_rsync.py` | The primary sync (SCP over SSH): `E:\Recordings` and `D:\PostExports\FBX` → `/web/gebarenoverleg_media/fbx` |
| `ftp_monitor.py` | Watches the Vicon FTP share for new recordings |
| `glb_matcher.py` | Pairs FBX files with their GLB counterparts |
| `compress_blackmagic.py` | Transcodes studio Blackmagic 6K clips to 1080p H.265 "mini" copies |
| `cleanup_vicon.py` | Reclaims space on the Vicon PC |

Scheduled by `pythonCron`, which calls `sync_vicon_rsync.py` directly. Its
credentials come from `vicon_credentials.get_vicon_password()` — the
`$VICON_PASSWORD` environment variable or an untracked `monitor_config.json`.

## signlab_studio_beta — Camera Control

**Live:** [signcollect.nl/studio_beta/opnameViewTest.html](https://signcollect.nl/studio_beta/opnameViewTest.html)
**Repo:** [signlab_studio_beta](https://github.com/Amsterdam-Humanities-Labs/signlab_studio_beta) · PHP

The studio-floor control page for FX30 recording sessions. Its first heading is
a shouted reminder to check that every battery is at least 50% charged, which
tells you what kind of page it is: the one an operator has open while running a
session.

`fx30proxy.php` proxies through to the `fx30MultiRecord` API described above, so
the browser never talks to the cameras directly. `fx30capturelog.php` and
`fx30debuglog.php` record what happened during a session.

Also carries `fetch_data.php`, `fetch_all2.php` and `fetch_last_capture.php` for
capture state, plus `nmm/` endpoints for non-manual-marker gloss lists.

> The bare folder returns 500 — there is no index page. Use the link above.

## signlab_mocapStudio — Motion Capture Studio

**Live:** [signcollect.nl/mocapStudio/3dOpname.html](https://signcollect.nl/mocapStudio/3dOpname.html)
**Repo:** [signlab_mocapStudio](https://github.com/Amsterdam-Humanities-Labs/signlab_mocapStudio) · PHP

The recording-session UI: it presents the sentence to be signed ("Glos hier"),
logs each take, and tracks which sentences still need capturing.

| Endpoint | Does |
|---|---|
| `getTeksten.php` / `getZinnen.php` | Fetch the sentences to record |
| `logMocapRecording.php` | Record that a take happened |
| `getMocapStats.php` | Progress statistics |
| `checkZinVideos.php`, `checkZinVideosFfprobe.php` | Verify the resulting videos exist and are readable |
| `reencodeZinVideos.php` | Re-encode takes that need it |
| `updateBakMocap.php`, `updateZinMocap.php`, `updateTekstMocap.php` | Update capture status |
| `triggerSync.php` | Kick off a sync rather than waiting for the scheduler |
| `getBakLabels.php` | Bak (tray/batch) labels |

> The bare folder returns 500. Use the link above.

---

# Part 2 — Scheduling

## signlab_pythonCron

**Repo:** [signlab_pythonCron](https://github.com/Amsterdam-Humanities-Labs/signlab_pythonCron) · Python

Runs every recurring job on the production host and restarts the ones that die.
Roughly 16 services: media conversion, mocap record matching (`matchVicon.py`,
`matchRecords.py`), MySQL backups, EAF/SRT backups, lemma lookup, disk checks,
QR conversion.

**Two schedulers run side by side.** This is deliberate and transitional, not a
mistake:

- **Wrapper architecture** (the current direction) — one long-lived process and
  one systemd unit per service, driven by `services_config.json` and supervised
  by `watchdog_daemon.py`. New services go here.
- **Centralized scheduler v2** — the older `scheduler_v2.py` path driven by
  `config.json`.

⚠️ **This repo mirrors a live production system.** Read its operational notes
before running anything; a careless local run can act on production data.

---

# Part 3 — Annotation and glossing

The tools researchers actually spend their day in.

## signlab_zin — the main annotation tool

**Live:** [signcollect.nl/zin/zinnen.html](https://signcollect.nl/zin/zinnen.html) (sentence browser — start here)
**Repo:** [signlab_zin](https://github.com/Amsterdam-Humanities-Labs/signlab_zin) · PHP + Python · the largest repo in the platform

A web-based sign-language annotation tool for building and editing
subtitle/gloss tracks. It synchronises Dutch text, Signbank glosses and
gesture-by-gesture annotation against a video timeline.

**The annotation workflow:**

1. Load a video and let it decode frames (long videos take a while — this buys
   you exact frame-by-frame scrubbing).
2. Create subtitle segments on the timeline.
3. Fill in the annotation tiers — *Nederlands* (Dutch), *Signbank ID glossen*,
   *Gebaar-voor-gebaar* (sign-by-sign).
4. Export to **EAF** (ELAN) for linguistic analysis.
5. Generate **SRT** subtitles for the video.

**Interface.** `zinnen.html` is the sentence browser and the launcher — from
there the `editEAF-AI` button opens the subtitle editor and `editMocap` opens
the 3D annotator:

| Page | Tool |
|---|---|
| [zinnen.html](https://signcollect.nl/zin/zinnen.html) | Sentence browser and launcher |
| [subBeta8.html](https://signcollect.nl/zin/subBeta8.html) | AI-assisted subtitle editor (current production editor) |
| [3DAnn2.html](https://signcollect.nl/zin/3DAnn2.html) | 3D motion-capture annotator |

**Backend.** `getZinnen.php` is the core API and does nearly everything:
`fetchSentences`, `fetchRow`, `saveSubtitlesAndEAFFiles`, `editZin`,
`uploadEAF`/`downloadEAF`, `deleteVideo`/`deleteZin`/`deleteEAF`, and the
`findGloss`/`findgvg` search calls. EAF files and SRT exports live under
`eaf/zin/`.

Timeline editing is canvas-based with zoom and scroll, drag-and-drop segment
positioning, and multiple simultaneous tiers. EAF files are backed up
automatically.

> The bare `/zin/` folder returns 500 — there is no index. Use `zinnen.html`.

## signlab_annotation-tool — standalone EAF editor

**Live:** [signcollect.nl/annotation-tool/](https://signcollect.nl/annotation-tool/)
**Repo:** [signlab_annotation-tool](https://github.com/Amsterdam-Humanities-Labs/signlab_annotation-tool) · JavaScript

A self-contained, browser-only editor for annotating sign-language video on a
multi-tier timeline and saving the result as an ELAN **EAF** file. **No server,
no database, no login.** Your video is read locally and never uploaded.

This exists for the case `zin` cannot cover: annotating material that is not in
the database, on any machine, without an account.

**Requires Chrome or Edge on desktop.** Autosave uses the File System Access
API, which Firefox and Safari do not implement. Everything else works
everywhere, but you would have to export by hand.

**Using it:**

1. Open the page and **drop an `.mp4`** onto it — optionally drop an `.eaf` at
   the same time to load existing annotations.
2. **Tiers.** You start with `Tier 1`; **+ Tier** adds more. Double-click a
   tier's name chip to rename, `×` to delete it (which deletes its annotations;
   one tier always remains). Dropping an `.eaf` replaces the tiers with the ones
   in the file, one row per `<TIER>`.
3. **Annotate.** Add boxes on the timeline, type text, drag to move, drag edges
   to resize, drag vertically to move a box between tiers.
4. **Autosave.** On the first change the browser asks you to pick a folder. From
   then on it writes `<video-name>.eaf` there about a second after each change.
   Only the `.eaf` is written — your video file is never touched. The folder is
   remembered in IndexedDB and survives reloads.
5. **Restore.** Reopening the page offers to restore the saved `.eaf`. You must
   re-drop the video, unless it sits in the same folder under a matching name,
   in which case it reloads itself.

## signlab_annotation-editors

**Repo:** [signlab_annotation-editors](https://github.com/Amsterdam-Humanities-Labs/signlab_annotation-editors) · PHP

Self-contained extracts of the two production editors launched from
`zinnen.html`, each in its own runnable subfolder — pulled out of `/web/zin`
without disturbing the originals.

| Folder | Tool | Launched in `zin` by |
|---|---|---|
| `subBeta8/` | AI-assisted subtitle editor | the `editEAF-AI` button |
| `3DAnn2/` | 3D motion-capture annotator | the `editMocap` button |

Each subfolder is its own web docroot, with a two-level layout mirroring the
original so no include or asset paths had to change. Serve a subfolder's root as
docroot and open `/zin/<tool>.html`.

Use this when you want to run, test or modify one editor in isolation. The live
copies remain the ones inside `zin`.

Remote services stay remote and are not bundled: `signcollect.nl/sign-segmenter`,
`/sign-spotter`, the `/ISS_Server/ws` websocket, and media under
`gebarenoverleg_media/studioFilesMini/`.

## signlab_signCollect-v2 — gloss management

**Live:** [signcollect.nl/menu_beta/](https://signcollect.nl/menu_beta/)
**Repo:** [signlab_signCollect-v2](https://github.com/Amsterdam-Humanities-Labs/signlab_signCollect-v2) · JavaScript + PHP
**Deploys to:** `/web/menu_beta/` — note the directory does *not* match the repo name

A from-scratch rebuild of the gloss editor. Browse and edit glosses from
`form_data`: paginated table, filters, inline editing, self-capture video
recording, and studio videos linked through
`matched_transcriptions.m_transcription = form_data.id`.

| Area | Contents |
|---|---|
| `php_api/` | Backend endpoints — `glosses_list`, `glosses_save`, `lsm_video_upload`, `phonology_get`, `logbook_get`, … |
| `signbank_sync/` | Two-way sync with Signbank — `push_gloss`, `fetch_gloss`, `force_pull`, `force_push` |
| `docs/spec.md` | The data model. **Read this before touching `form_data`.** |

Authentication is the shared `sessionObject` cookie on `.signcollect.nl`.

---

# Part 4 — Browsing and review

## signlab_studioIndex — Studio Index

**Live:** [signcollect.nl/studioIndex/](https://signcollect.nl/studioIndex/)
**Repo:** [signlab_studioIndex](https://github.com/Amsterdam-Humanities-Labs/signlab_studioIndex) · PHP

Browse the sign-language studio archive by date, with per-date completion
status. This is the "what did we actually record, and is it all there?" view.

| Endpoint | Does |
|---|---|
| `getStudioFiles.php` | List the files recorded on a date |
| `getDateStatus.php` | Completion status for a date |
| `getStatusCache.php` | Cached status, so the index stays fast |
| `api.php` | Front-end data endpoint |

## signlab_viconDashboard — Vicon Capture Dashboard

**Live:** [signcollect.nl/viconDashboard/](https://signcollect.nl/viconDashboard/)
**Repo:** [signlab_viconDashboard](https://github.com/Amsterdam-Humanities-Labs/signlab_viconDashboard) · PHP + JS

Real-time dashboard for Vicon mocap sessions: capture status, file completions,
and links into the 3D viewer. Vanilla JS + Bootstrap 5 + Chart.js over PHP.

**Using it:**

- **Auto-refresh** every 30 seconds, toggleable.
- **Date filter** — click a date in the left sidebar to filter captures.
- **Row expansion** — click a capture row to see its file list.
- **Tekst column** links to the 3D viewer when a GLB exists.
- **CC/Vicon columns** only appear for captures from 2026-02-17 onwards.

**Reading the status colours** — this is the part worth knowing:

| Colour | Means |
|---|---|
| 🟢 Green | All five required subdirectories present **and** no files still growing |
| 🟡 Yellow | All five present **but** files are still growing (upload in progress) |
| 🔴 Red | Incomplete — a required subdirectory is missing |

The five required subdirectories are `obs`, `shogun_live`, `unreal`, `livelink`
and `metadata`. Note that `livelink` status is *derived from CSV files in the
`unreal` subdirectory* — there is no physical `livelink` directory.

**Storage.** Files originate on the Windows recording machine under
`E:\Recordings\{date}\{recording_dir}\{subdirectory}\` and sync to
`/mnt/bigstorage/`, surfaced through symlinks in `/web/gebarenoverleg_media/`:
`razerFiles/` (OBS video), `shogun_live/`, `fbx/`. Not everything is synced —
livelink CSV, metadata JSON, `unreal/CC`, `unreal/Vicon` and shogun_post files
exist only on the Windows machine. If a file is missing from the web, check
there before assuming it was lost.

API: `get_live_feed.php`, `get_capture_files.php`, `get_date_overview.php`,
`get_mocap_stats.php`.

## signlab_mocap — Motion Capture NGT Recordings

**Live:** [signcollect.nl/mocap/](https://signcollect.nl/mocap/) · recording list: [opnameLijst.html](https://signcollect.nl/mocap/opnameLijst.html)
**Repo:** [signlab_mocap](https://github.com/Amsterdam-Humanities-Labs/signlab_mocap) · Python + PHP

The capture register: which NGT recordings exist, what state they are in, and
the importers that get external data into the database.

| Endpoint / script | Does |
|---|---|
| `getCaptures.php`, `getRecords.php`, `fetch_all.php` | Read the capture register |
| `addCaptures.php` | Add capture records |
| `uploadOBS.php` | Receive OBS recordings |
| `get50mocapfiles.php` | Paged file listing |
| `getCSLRecords.php`, `updateCSLRecord.php`, `index_csl.html` | The CSL record set |
| `matchRecords.py`, `matchVicon.py` | Match recordings to sentences — also run on a schedule by `pythonCron` |
| `csl_to_sql.py`, `csv_to_sql_sit.py`, `jsonToSql.py` | Importers into MySQL |
| `detect_duplicates.py`, `files_checker.py`, `video_checker.py` | Integrity checks |

## signlab_mocap_site — Motion Capture Portal

**Live:** [signcollect.nl/mocap_site/](https://signcollect.nl/mocap_site/)
**Repo:** [mocap_site](https://github.com/Amsterdam-Humanities-Labs/mocap_site) — ⚠️ the one repo still missing the `signlab_` prefix

A single-page portal that acts as the entry point into the motion-capture
tools. One `index.html`, no backend.

## signlab_mocap_lab

**Repo:** [signlab_mocap_lab](https://github.com/Amsterdam-Humanities-Labs/signlab_mocap_lab) · PHP

A collection of lab endpoints and reference media rather than an application —
there is no index page, and the bare folder returns 500.

| Endpoint | Does |
|---|---|
| `fetch_images.php`, `fetch_topics.php` | Serve reference imagery and topic lists |
| `generate_video_files.php` | Produce video file records |
| `save_fbx_studio.php`, `saveThree.php` | Receive FBX and three-dimensional capture output |

Most of its bulk is reference media (JPG, PNG, MP4, MOV) used by the lab pages.

## signlab_mocapDataPackage

**Endpoint:** `https://signcollect.nl/mocapDataPackage/upload.php` (POST only — a bare GET returns 405, which is correct)
**Repo:** [signlab_mocapDataPackage](https://github.com/Amsterdam-Humanities-Labs/signlab_mocapDataPackage) · PHP

A PHP endpoint that receives and stores zip files of capture data. It accepts
unlimited file sizes and saves them to a configured directory under their
original filenames.

There is no user interface — this is the drop-off point that capture machines
POST to. `batch_process.php` and `extract_fbx_batch.py` handle what arrives.

---

# Part 5 — Media processing

## signlab_videoFix — Crop Fix Manager

**Live:** [signcollect.nl/videoFix/](https://signcollect.nl/videoFix/)
**Repo:** [signlab_videoFix](https://github.com/Amsterdam-Humanities-Labs/signlab_videoFix) · PHP

Tracks and applies per-video crop corrections. Videos whose framing is wrong get
a recorded fix; the interface is a paged, searchable queue split into
**unresolved** and **resolved**.

| Action (`api.php?action=…`) | Does |
|---|---|
| `get_unresolved`, `get_resolved` | The two work queues |
| `get_fixes` | Fixes recorded for a video |
| `add_fix`, `remove_fix` | Record or withdraw a crop fix |
| `update_status` | Move an item between queues |
| `update_oob` | Flag out-of-bounds framing |
| `populate_from_labels` | Seed the queue from existing labels |
| `search` | Find a specific video |

Recorded fixes live in `crop_fixes.json`.

## signlab_videoBackgroundFix

**Live:** [signcollect.nl/videoBackgroundFix/](https://signcollect.nl/videoBackgroundFix/)
**Repo:** [signlab_videoBackgroundFix](https://github.com/Amsterdam-Humanities-Labs/signlab_videoBackgroundFix) · PHP

Background and framing correction for studio clips, built around a job queue so
long ffmpeg runs do not block the browser.

**The workflow:** pick a date → list its clips → generate a **preview frame** or
**preview video** to check the result → submit the job → watch its status →
cancel or restore if it went wrong.

| Endpoint (`api/`) | Does |
|---|---|
| `dates.php`, `list.php` | Browse dates and their clips |
| `preview_frame.php`, `preview_video.php` | Preview before committing |
| `process.php` | Queue the actual job |
| `jobs.php`, `status.php` | Monitor the queue |
| `cancel.php`, `restore.php` | Abort a job, or put the original back |

Its design notes are under `docs/superpowers/`. Current behaviour widens clips
to 1.15:1 with blue side bars and centres the person, anchoring on the top of
the head with a 200 px margin.

## signlab_sC-Animation-PP — animation post-processing

**Live:** [signcollect.nl/animMIDI/public/](https://signcollect.nl/animMIDI/public/) — note the `public/` docroot
**Repo:** [signlab_sC-Animation-PP](https://github.com/Amsterdam-Humanities-Labs/signlab_sC-Animation-PP) · PHP

The human step in the mocap pipeline. Engineers download the original FBX
captures, clean them up in Unreal Engine, and upload the processed versions
back. The app tracks who holds which capture date and what state each file is
in.

**Using it:** an admin delegates a capture date to one user; that user
downloads, works in Unreal, and uploads the result. Every download, upload and
status change is logged with a timestamp, so the audit trail is the point as
much as the file transfer.

It reads the `vicon_files` table — specifically the `unreal/CC` subdirectory of
what `viconSync` lands on disk, which is exactly what ties this repo to the
capture side.

Includes a BabylonJS viewer for 3D preview and a side-by-side original vs
processed comparison with per-bone rotation compensation.

PHP 7.4+ MVC with PDO and Tailwind via CDN. No build step.

---

# Part 6 — 3D viewers and assets

## signlab_s3b_glb — GLB Viewer (Gebarenstrand)

**Live:** [signcollect.nl/s3b_glb/](https://signcollect.nl/s3b_glb/) · viewer: [gs.html](https://signcollect.nl/s3b_glb/gs.html)
**Repo:** [signlab_s3b_glb](https://github.com/Amsterdam-Humanities-Labs/signlab_s3b_glb) · PHP

Browse and play GLB captures from the collection with playback controls and an
annotation affordance. Backed by pre-built caches so it stays responsive:
`gloss_cache.json`, `sense_index_cache.json`, `vtt_set_cache.json`, and
`gebarenstrand_files.json`.

## signlab_s3b_server — SAM3D-body server

**Live:** [top50.html](https://signcollect.nl/s3b_server/top50.html) (Top 50 Hand Clusters Viewer) · [hand_mesh.html](https://signcollect.nl/s3b_server/hand_mesh.html) (pure-CSS 3D hand)
**Repo:** [signlab_s3b_server](https://github.com/Amsterdam-Humanities-Labs/signlab_s3b_server) · PHP + Python

Receives SAM3D-body uploads and clusters hand shapes, with viewers over the
result. `cluster.py` does the clustering, `find_highest_count.py` picks out the
most frequent shapes, and `list_uploads.php` / `get_sam3dbody_files.php` expose
what has been uploaded. `lockFile.php` guards concurrent processing.

Cluster output lands in `top50_hand_clusters.json` and `all_hand_clusters.json`,
with rendered angle images under `visualizations/`.

## signlab_s3b_viewer — SAM 3D Body Viewer

**Live:** [signcollect.nl/s3b_viewer/viewer.html](https://signcollect.nl/s3b_viewer/viewer.html)
**Repo:** [signlab_s3b_viewer](https://github.com/Amsterdam-Humanities-Labs/signlab_s3b_viewer) · PHP

A deliberately minimal standalone viewer — one `viewer.html` over a single
`api/files.php` file listing, with loop and mute controls. Use it when you want
to look at a capture without loading the full `s3b_server` interface.

> The bare folder returns 500. Use `viewer.html`.

## signlab_mhr — MHR avatar assets

**Repo:** [signlab_mhr](https://github.com/Amsterdam-Humanities-Labs/signlab_mhr) · assets only, no interface

Mesh and animation sources for the MHR avatar. The three real files —
`animated_body.glb` (456 MB), `mhr_animated.blend` (136 MB) and `lod0.fbx`
(29 MB) — **exceed GitHub's 100 MB limit and are gitignored**, so the repo holds
only a README documenting them.

To version them properly, set up [Git LFS](https://git-lfs.com/) and
`git lfs track "*.glb" "*.blend" "*.fbx"` before re-adding. Until then the files
live only on the server. Related: `mhr_to_blender`.

---

# Part 7 — Serving and monitoring

## signlab_sCAPI — the public API

**Live:** [api.signcollect.nl](https://api.signcollect.nl)
**Repo:** [signlab_sCAPI](https://github.com/Amsterdam-Humanities-Labs/signlab_sCAPI) · PHP
**Deploys to:** `/web/zin/api` — it sits *inside* the `zin` deployment

The read API over the sign video collection. Search across words, sentences and
glosses with theme grouping and pagination, plus the `getList*` and `get*Videos`
endpoints.

**Search semantics worth knowing:** single-word queries use lemma-based search;
multi-word queries require **all** words to match.

> `zin` records this as a git submodule-style link with no `.gitmodules` entry,
> so cloning `signlab_zin` gives you an empty `api/` directory. Clone this repo
> separately into `zin/api` if you need the backend.

## signlab_client_monitor_api

**Endpoint:** `https://signcollect.nl/client_monitor_api/api.php` (a bare GET returns 400 — it needs an `action`)
**Repo:** [signlab_client_monitor_api](https://github.com/Amsterdam-Humanities-Labs/signlab_client_monitor_api) · PHP + Python

Registration and heartbeat API for every long-running script and cron job.
Missing heartbeats are how a silently dead job gets noticed.

| `?action=` | Does |
|---|---|
| `register` | Register a client |
| `heartbeat` | Report still-alive, with stats |
| `get_clients`, `get_client` | Read registered clients |
| `update_client`, `delete_client` | Maintain the register |
| `submit_metrics`, `get_metrics` | Push and read metrics |
| `get_stats` | Aggregate statistics |

**Registering a client:**

```bash
curl -X POST 'https://signcollect.nl/client_monitor_api/api.php?action=register' \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "my-cron-job",
    "client_name": "Daily Backup Job",
    "description": "Runs daily at 2 AM to backup database",
    "heartbeat_interval": 3600,
    "metadata": {"version": "1.0.0", "server": "prod-01"}
  }'
```

Client IDs follow a `vicon-*` convention: `vicon-sync-rsync`,
`vicon-ftp-monitor`, `vicon-glb-matcher`, `vicon-blackmagic-mini`.

**Monitoring is always optional.** If the API is unreachable a client logs a
warning and carries on — sync work is never blocked by a monitoring failure.
This is a deliberate design choice; do not "fix" it by making it fatal.

⚠️ The `ClientMonitor` class lives in a `python_client.py` that has been
**copied** into each repo rather than shared, and the copies have drifted. If
you change one, check whether the others need the same change.

## signlab_client_monitor_dashboard

**Live:** [signcollect.nl/client_monitor_dashboard/](https://signcollect.nl/client_monitor_dashboard/)
**Repo:** [signlab_client_monitor_dashboard](https://github.com/Amsterdam-Humanities-Labs/signlab_client_monitor_dashboard) · PHP + JS

The web dashboard over the monitor API: every connected client with its status,
auto-refreshing. Status is derived from whether a heartbeat arrived inside the
client's declared `heartbeat_interval` — **Online**, **Warning** or **Offline**.

Authentication is PHP session-based.

---

# Part 8 — Archive

## signlab_hh — Dutch health-content indexing (dormant)

**Live:** [signcollect.nl/hh/](https://signcollect.nl/hh/)
**Repo:** [signlab_hh](https://github.com/Amsterdam-Humanities-Labs/signlab_hh) · HTML + Python · **dormant since 2025-07-04**

Crawls medical content from `thuisarts.nl`, lemmatises it with
OpenDutchWordnet, and presents it through a browsing and search interface:
`crawl.py` → `json_to_db.py` → `create_unique_words_table.py` → `lemma_load.py`,
with autocue and concept-list pages on top.

It sits at the edge of the platform rather than inside it. The connection is
vocabulary: it queries glosses across Signbank and SignCollect in the same
`admin_gebarenoverleg` database, and its lemma work overlaps the
`convert_zinString_to_LemmaList` job that `pythonCron` runs. Nothing in the live
capture-to-API path depends on it.

**Treat it as an archive.** Every commit lands on a single day. Most of its bulk
is the vendored `OpenDutchWordnet` tree, not project code. Read it for the
crawler and lemmatisation approach; do not expect it to run as-is.

---

## Troubleshooting

**A page returns 500.** Most likely there is no index file in that directory —
check the entry point in this manual rather than opening the bare folder.

**A script cannot reach the database.** Check that the gitignored
`db_credentials.py` / `db_credentials.php` / `mysql_config.php` exists in the
deployment and is readable by the process that needs it. PHP runs as
`www-data`; if the file is mode 600 owned by another user, PHP cannot read it.

**Every `bmcam` call 404s.** Web Media Manager and the REST API are not enabled
in the Blackmagic camera's settings.

**Vicon sync stopped after a Windows reinstall.** The Vicon PC's tailnet address
changed. `vicon_host.py` should rediscover it from `tailscale status`.

**A capture is stuck yellow in the dashboard.** All five subdirectories arrived
but files are still growing — the upload has not finished. Red means a required
subdirectory is genuinely missing.

**A file is missing from the web but exists on the recording machine.** Not
every subdirectory is synced: livelink CSV, metadata JSON, `unreal/CC`,
`unreal/Vicon` and shogun_post files stay on Windows by design.
