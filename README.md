# signlab_signcollect-stack

An index of the repositories behind SignCollect and Zin, the platform that
collects sign language data. It covers studio capture, media processing, the
gloss database and the public API. This repo holds no application code. Each
repo's own README says what it does.

| Doc | Read it when you want to know |
|---|---|
| [docs/architecture.md](docs/architecture.md) | How the repos fit together (diagram), and the main database tables |
| [docs/machines.md](docs/machines.md) | What runs on each machine, and the unit, timer or cron name it runs as |
| [docs/runbook.md](docs/runbook.md) | What to do when something breaks: first checks, unit names, blast radius, restarts, disk full |
| [docs/schema.md](docs/schema.md) | What each database table holds, and which repos write and read it |
| [docs/install.md](docs/install.md) | How to set up a demo or test host (the only install doc) |
| [docs/deploy.md](docs/deploy.md) | How a deploy works, and how to add a component repo |
| [docs/production.md](docs/production.md) | How the core server is laid out: what is checked out where, how it is updated, pending switch-overs |
| [docs/readme-template.md](docs/readme-template.md) | Which README skeleton every repo follows |
| [docs/data-storage.md](docs/data-storage.md) | Which datasets go to UvA LVS instead of git, and how to package them |

All repos are in the [Amsterdam-Humanities-Labs](https://github.com/orgs/Amsterdam-Humanities-Labs/repositories?q=signlab_)
organisation, with a `signlab_` prefix. Every member has access. All repos are
private except `signlab_Sony-SDK-MACOS-API` and `signlab_BabylonSignLab`.

## The repositories

There are 36 repositories, plus the deploy toolchain in this repo. Entry paths
are on `https://signcollect.nl` unless a full host is given. Open the entry
point. The bare folder often returns a 500 error.

Tiers:
- 1: core data path (camera → storage → database → interface/API). Production breaks without it.
- 2: supporting: monitoring, tools used weekly, demo/deploy.
- 3: experimental or dormant.

The tiers come from [machines.md](docs/machines.md), the [runbook](docs/runbook.md#blast-radius) blast radius, `repos.tsv` and the Status in each README.

| Repo | Tier | Layer | Role | Language | Server | Status | Entry point |
|---|---|---|---|---|---|---|---|
| [signlab_viconSync](https://github.com/Amsterdam-Humanities-Labs/signlab_viconSync) | 1 | Core stack | Vicon capture ingest | Python | core server | production | — (systemd units) |
| [signlab_blackmagic_control](https://github.com/Amsterdam-Humanities-Labs/signlab_blackmagic_control) | 1 | Core stack | `bmcam`, Blackmagic camera control | Python | Vicon PC | production | `bmcam serve` on :8000 |
| [signlab_blackmagic_RD_sync](https://github.com/Amsterdam-Humanities-Labs/signlab_blackmagic_RD_sync) | 1 | Core stack | Camera → research drive sync | Python | Vicon PC | production | — |
| [signlab_Sony-SDK-MACOS-API](https://github.com/Amsterdam-Humanities-Labs/signlab_Sony-SDK-MACOS-API) | 1 | Core stack | FX30 multi-camera controller | C++ | DRS | production | `http://localhost:8080` on DRS |
| [signlab_drs-pipeline](https://github.com/Amsterdam-Humanities-Labs/signlab_drs-pipeline) | 1 | Core stack | Video pipeline: DaVinci render, AI crop, upload | Python + JS | DRS | production | `startupScript.py` on DRS |
| [signlab_pythonCron](https://github.com/Amsterdam-Humanities-Labs/signlab_pythonCron) | 1 | Core stack | Scheduler and watchdog | Python | core server | production | — (systemd units) |
| [signlab_mocap-postprocessing](https://github.com/Amsterdam-Humanities-Labs/signlab_mocap-postprocessing) | 1 | Core stack | Animation post-processing manager | PHP | core server | production | [/animMIDI/public/](https://signcollect.nl/animMIDI/public/) |
| [signlab_signCollect-API-TYD](https://github.com/Amsterdam-Humanities-Labs/signlab_signCollect-API-TYD) | 1 | Core stack | Public read API | PHP | core server | production | [api.signcollect.nl](https://api.signcollect.nl) |
| [signlab_signCollect-v2](https://github.com/Amsterdam-Humanities-Labs/signlab_signCollect-v2) | 1 | Core stack | Gloss management interface | JavaScript + PHP | core server | production | [/menu_beta/](https://signcollect.nl/menu_beta/) |
| [signlab_patient-info](https://github.com/Amsterdam-Humanities-Labs/signlab_patient-info) | 3 | Core stack | Dutch health-content indexing | HTML + Python | core server | dormant | [/hh/](https://signcollect.nl/hh/) |
| [signlab_signcollect-lib](https://github.com/Amsterdam-Humanities-Labs/signlab_signcollect-lib) | 1 | Shared | Database config + install-root resolver | PHP | core server | production | — (`/web/lib`, not servable) |
| [signlab_zinnen-annotation](https://github.com/Amsterdam-Humanities-Labs/signlab_zinnen-annotation) | 1 | Annotation | The main annotation tool | PHP + Python | core server | production | [/zin/zinnen.html](https://signcollect.nl/zin/zinnen.html) |
| [signlab_annotation-tool](https://github.com/Amsterdam-Humanities-Labs/signlab_annotation-tool) | 2 | Annotation | Standalone EAF editor | JavaScript | core server (runs in the browser) | production | [/annotation-tool/](https://signcollect.nl/annotation-tool/) |
| [signlab_annotation-editors](https://github.com/Amsterdam-Humanities-Labs/signlab_annotation-editors) | 1 | Annotation | The two zinnen-annotation editors, extracted | PHP | core server | production | launched from `zinnen.html` |
| [signlab_mocapStudio](https://github.com/Amsterdam-Humanities-Labs/signlab_mocapStudio) | 1 | Studio & mocap | Motion Capture Studio UI | PHP | core server | production | [/mocapStudio/3dOpname.html](https://signcollect.nl/mocapStudio/3dOpname.html) |
| [signlab_studio-archive](https://github.com/Amsterdam-Humanities-Labs/signlab_studio-archive) | 2 | Studio & mocap | Studio archive, by date | PHP | core server | production | [/studioIndex/](https://signcollect.nl/studioIndex/) |
| [signlab_camera-control](https://github.com/Amsterdam-Humanities-Labs/signlab_camera-control) | 1 | Studio & mocap | Camera Control | PHP | core server | production | [/studio_beta/opnameViewTest.html](https://signcollect.nl/studio_beta/opnameViewTest.html) |
| [signlab_mocap](https://github.com/Amsterdam-Humanities-Labs/signlab_mocap) | 1 | Studio & mocap | Capture register and importers | Python + PHP | core server | production | [/mocap/opnameLijst.html](https://signcollect.nl/mocap/opnameLijst.html) |
| [signlab_mocap_lab](https://github.com/Amsterdam-Humanities-Labs/signlab_mocap_lab) | 1 | Studio & mocap | Lab capture endpoints, merged into `signlab_mocapStudio/lab/` | PHP | core server | archived | endpoints only, no index (bare folder 500s) |
| [signlab_mocapDataPackage](https://github.com/Amsterdam-Humanities-Labs/signlab_mocapDataPackage) | 3 | Studio & mocap | Capture-package upload endpoint | PHP | core server | archived (dormant) | `/mocapDataPackage/upload.php` (POST) |
| [signlab_viconDashboard](https://github.com/Amsterdam-Humanities-Labs/signlab_viconDashboard) | 2 | Studio & mocap | Live Vicon session dashboard | PHP + JS | core server | production | [/viconDashboard/](https://signcollect.nl/viconDashboard/) |
| [signlab_mocap_site](https://github.com/Amsterdam-Humanities-Labs/signlab_mocap_site) | 2 | Studio & mocap | Motion Capture Portal entry point | HTML | core server | production | [/mocap_site/](https://signcollect.nl/mocap_site/) |
| [signlab_crop-fix-manager](https://github.com/Amsterdam-Humanities-Labs/signlab_crop-fix-manager) | 2 | Video | Crop Fix Manager | PHP | core server | production | [/videoFix/](https://signcollect.nl/videoFix/) |
| [signlab_background-fix](https://github.com/Amsterdam-Humanities-Labs/signlab_background-fix) | 2 | Video | Background and framing correction | PHP | core server | production | [/videoBackgroundFix/](https://signcollect.nl/videoBackgroundFix/) |
| [signlab_body-animation-viewer](https://github.com/Amsterdam-Humanities-Labs/signlab_body-animation-viewer) | 3 | 3D & assets | GLB viewer | PHP | core server | experimental | [/s3b_glb/gs.html](https://signcollect.nl/s3b_glb/gs.html) |
| [signlab_sam3d-body-queue](https://github.com/Amsterdam-Humanities-Labs/signlab_sam3d-body-queue) | 3 | 3D & assets | SAM3D upload and hand clustering | PHP + Python | core server | experimental | [/s3b_server/top50.html](https://signcollect.nl/s3b_server/top50.html) |
| [signlab_s3b_viewer](https://github.com/Amsterdam-Humanities-Labs/signlab_s3b_viewer) | 3 | 3D & assets | Standalone SAM 3D Body viewer, merged into `signlab_sam3d-body-queue/viewer/` | PHP | core server | archived | [/s3b_viewer/viewer.html](https://signcollect.nl/s3b_viewer/viewer.html) |
| [signlab_blendbaking](https://github.com/Amsterdam-Humanities-Labs/signlab_blendbaking) | 2 | 3D & assets | `blendBaking` and the avatar site | PHP | core server | production | [avatar.signcollect.nl](https://avatar.signcollect.nl) |
| [signlab_BabylonSignLab](https://github.com/Amsterdam-Humanities-Labs/signlab_BabylonSignLab) | 3 | 3D & assets | Babylon.js animation viewer (fork of the copy in `/web/jari/BabylonSignLab`) | JavaScript | core server | experimental | not deployed from the repo |
| [signlab_mhr](https://github.com/Amsterdam-Humanities-Labs/signlab_mhr) | 3 | 3D & assets | MHR avatar source assets, merged into `signlab_sam3d-body-queue/mhr/` | — | core server (assets, not a service) | archived | — |
| [signlab_client_monitor_api](https://github.com/Amsterdam-Humanities-Labs/signlab_client_monitor_api) | 2 | Monitoring | Registration and heartbeat API | PHP + Python | core server | production | `/client_monitor_api/api.php?action=…` |
| [signlab_client_monitor_dashboard](https://github.com/Amsterdam-Humanities-Labs/signlab_client_monitor_dashboard) | 2 | Monitoring | Dashboard over that API | PHP + JS | core server | production | [/client_monitor_dashboard/](https://signcollect.nl/client_monitor_dashboard/) |
| [signlab_qr](https://github.com/Amsterdam-Humanities-Labs/signlab_qr) | 1 | Core stack | Stores DRS QR scan results in `matched_transcriptions` | PHP | core server | production (copy, not deployed from the repo) | `/qr/qrResultReceiver.php` (POST) |
| [signlab_helpScripts](https://github.com/Amsterdam-Humanities-Labs/signlab_helpScripts) | 2 | Tools | Helper endpoints, server jobs and one-off scripts | Python + PHP | core server | production (copy, not deployed from the repo) | `/helpScripts/emptyVideoTop.php` |
| [signlab_josBoard](https://github.com/Amsterdam-Humanities-Labs/signlab_josBoard) | 2 | Tools | Josje-Board: how often target words occur in sentences | PHP + Python | core server | production (copy, not deployed from the repo) | [/josBoard/](https://signcollect.nl/josBoard/) |
| [signlab_demo-media](https://github.com/Amsterdam-Humanities-Labs/signlab_demo-media) | 2 | Deployment | Demo video for seeding a demo host | — | demo hosts | production | — |
| [interface_deploy](interface_deploy) | 2 | Deployment | The deploy toolchain. Lives in this repo | Bash + PHP | demo hosts | production | — |

## Where things run

| Server | What it is |
|---|---|
| core server | The production VPS (`cloud`) that serves `signcollect.nl`. Runs everything under `/web`, plus services in `/opt` and `/home/gomer` such as `pythonCron` |
| Vicon PC | Windows PC in the Visualisation Lab. Runs `bmcam` and RD_sync. `viconSync` runs on the core server and pulls from the Vicon PC |
| DRS | The studio Mac with the Sony FX30s on USB. Runs Sony-SDK and `signlab_drs-pipeline` |
| demo hosts | Isolated copies built by [install.md](docs/install.md): `dev2` (demo, `/web`), `stijn` (test, `stijn.taila8bdbd.ts.net`, bare Ubuntu 24.04, `--local`), `dev-1` (`/srv/signcollect/web`) |

Full detail per machine, with unit names: [docs/machines.md](docs/machines.md).
Older specs name `dev` (100.72.57.25). It is offline.

## interface_deploy

[`interface_deploy/`](interface_deploy) is a `git subtree` copy of a separate
repository. Read it here, but commit changes upstream. Edits made here are lost
on the next sync.
