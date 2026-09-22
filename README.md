# SignCollect Stack

Index of the repositories behind **SignCollect / Zin**, the sign-language data
collection platform: studio capture, media processing, the gloss database and
the public API. No application code lives here. What each repo does is in its
own README.

| Doc | What it answers |
|---|---|
| [docs/architecture.md](docs/architecture.md) | How the repos fit together (diagram) and the main database tables |
| [docs/machines.md](docs/machines.md) | What runs on each machine, and the unit / timer / cron name it runs as |
| [docs/runbook.md](docs/runbook.md) | Something is broken: first checks, unit names, blast radius, restarts, disk full |
| [docs/schema.md](docs/schema.md) | Every database table: what it holds, which repo writes and reads it |
| [docs/install.md](docs/install.md) | Standing up a demo or test host (the only install doc) |
| [docs/deploy.md](docs/deploy.md) | How a deploy works, and adding a component repo |
| [docs/readme-template.md](docs/readme-template.md) | The README skeleton every repo follows |

All repos live in the [Amsterdam-Humanities-Labs](https://github.com/orgs/Amsterdam-Humanities-Labs/repositories?q=signlab_)
organisation under a `signlab_` prefix; every member has access. All are
private except `signlab_Sony-SDK-MACOS-API`.

## The repositories

32 repositories, plus the deploy toolchain in this one. Entry paths are on
`https://signcollect.nl` unless a full host is given; open the entry point, not
the bare folder, which often 500s.

Tier: **1** core data path (camera → storage → database → interface/API; production breaks without it).
**2** supporting: monitoring, tools used weekly, demo/deploy. **3** experimental or dormant.
Derived from [machines.md](docs/machines.md), the [runbook](docs/runbook.md#blast-radius) blast radius, `repos.tsv` and each README's Status.

| Repo | Tier | Layer | Role | Language | Server | Status | Entry point |
|---|---|---|---|---|---|---|---|
| [signlab_viconSync](https://github.com/Amsterdam-Humanities-Labs/signlab_viconSync) | 1 | Core stack | Vicon capture ingest | Python | core server | production | — (systemd units) |
| [signlab_blackmagic_control](https://github.com/Amsterdam-Humanities-Labs/signlab_blackmagic_control) | 1 | Core stack | `bmcam`, Blackmagic camera control | Python | Vicon PC | production | `bmcam serve` on :8000 |
| [signlab_blackmagic_RD_sync](https://github.com/Amsterdam-Humanities-Labs/signlab_blackmagic_RD_sync) | 1 | Core stack | Camera → research drive sync | Python | Vicon PC | production | — |
| [signlab_Sony-SDK-MACOS-API](https://github.com/Amsterdam-Humanities-Labs/signlab_Sony-SDK-MACOS-API) | 1 | Core stack | FX30 multi-camera controller | C++ | DRS | production | `http://localhost:8080` on DRS |
| [signlab_drs](https://github.com/Amsterdam-Humanities-Labs/signlab_drs) | 1 | Core stack | Video pipeline: DaVinci render, AI crop, upload | Python + JS | DRS | production | `startupScript.py` on DRS |
| [signlab_pythonCron](https://github.com/Amsterdam-Humanities-Labs/signlab_pythonCron) | 1 | Core stack | Scheduler and watchdog | Python | core server | production | — (systemd units) |
| [signlab_sC-Animation-PP](https://github.com/Amsterdam-Humanities-Labs/signlab_sC-Animation-PP) | 1 | Core stack | Animation post-processing manager | PHP | core server | production | [/animMIDI/public/](https://signcollect.nl/animMIDI/public/) |
| [signlab_sCAPI](https://github.com/Amsterdam-Humanities-Labs/signlab_sCAPI) | 1 | Core stack | Public read API | PHP | core server | production | [api.signcollect.nl](https://api.signcollect.nl) |
| [signlab_signCollect-v2](https://github.com/Amsterdam-Humanities-Labs/signlab_signCollect-v2) | 1 | Core stack | Gloss management interface | JavaScript + PHP | core server | production | [/menu_beta/](https://signcollect.nl/menu_beta/) |
| [signlab_hh](https://github.com/Amsterdam-Humanities-Labs/signlab_hh) | 3 | Core stack | Dutch health-content indexing | HTML + Python | core server | **dormant** | [/hh/](https://signcollect.nl/hh/) |
| [signlab_signcollect-lib](https://github.com/Amsterdam-Humanities-Labs/signlab_signcollect-lib) | 1 | Shared | Database config + install-root resolver | PHP | core server | production | — (`/web/lib`, not servable) |
| [signlab_zin](https://github.com/Amsterdam-Humanities-Labs/signlab_zin) | 1 | Annotation | The main annotation tool | PHP + Python | core server | production | [/zin/zinnen.html](https://signcollect.nl/zin/zinnen.html) |
| [signlab_annotation-tool](https://github.com/Amsterdam-Humanities-Labs/signlab_annotation-tool) | 2 | Annotation | Standalone EAF editor | JavaScript | core server (runs in the browser) | production | [/annotation-tool/](https://signcollect.nl/annotation-tool/) |
| [signlab_annotation-editors](https://github.com/Amsterdam-Humanities-Labs/signlab_annotation-editors) | 1 | Annotation | The two `zin` editors, extracted | PHP | core server | production | launched from `zinnen.html` |
| [signlab_mocapStudio](https://github.com/Amsterdam-Humanities-Labs/signlab_mocapStudio) | 1 | Studio & mocap | Motion Capture Studio UI | PHP | core server | production | [/mocapStudio/3dOpname.html](https://signcollect.nl/mocapStudio/3dOpname.html) |
| [signlab_studioIndex](https://github.com/Amsterdam-Humanities-Labs/signlab_studioIndex) | 2 | Studio & mocap | Studio archive, by date | PHP | core server | production | [/studioIndex/](https://signcollect.nl/studioIndex/) |
| [signlab_studio_beta](https://github.com/Amsterdam-Humanities-Labs/signlab_studio_beta) | 1 | Studio & mocap | Camera Control | PHP | core server | production | [/studio_beta/opnameViewTest.html](https://signcollect.nl/studio_beta/opnameViewTest.html) |
| [signlab_mocap](https://github.com/Amsterdam-Humanities-Labs/signlab_mocap) | 1 | Studio & mocap | Capture register and importers | Python + PHP | core server | production | [/mocap/opnameLijst.html](https://signcollect.nl/mocap/opnameLijst.html) |
| [signlab_mocap_lab](https://github.com/Amsterdam-Humanities-Labs/signlab_mocap_lab) | 1 | Studio & mocap | Lab capture endpoints | PHP | core server | production | endpoints only, no index (bare folder 500s) |
| [signlab_mocapDataPackage](https://github.com/Amsterdam-Humanities-Labs/signlab_mocapDataPackage) | 3 | Studio & mocap | Capture-package upload endpoint | PHP | core server | production | `/mocapDataPackage/upload.php` (POST) |
| [signlab_viconDashboard](https://github.com/Amsterdam-Humanities-Labs/signlab_viconDashboard) | 2 | Studio & mocap | Live Vicon session dashboard | PHP + JS | core server | production | [/viconDashboard/](https://signcollect.nl/viconDashboard/) |
| [signlab_mocap_site](https://github.com/Amsterdam-Humanities-Labs/signlab_mocap_site) | 2 | Studio & mocap | Motion Capture Portal entry point | HTML | core server | production | [/mocap_site/](https://signcollect.nl/mocap_site/) |
| [signlab_videoFix](https://github.com/Amsterdam-Humanities-Labs/signlab_videoFix) | 2 | Video | Crop Fix Manager | PHP | core server | production | [/videoFix/](https://signcollect.nl/videoFix/) |
| [signlab_videoBackgroundFix](https://github.com/Amsterdam-Humanities-Labs/signlab_videoBackgroundFix) | 2 | Video | Background and framing correction | PHP | core server | production | [/videoBackgroundFix/](https://signcollect.nl/videoBackgroundFix/) |
| [signlab_s3b_glb](https://github.com/Amsterdam-Humanities-Labs/signlab_s3b_glb) | 3 | 3D & assets | GLB viewer | PHP | core server | experimental | [/s3b_glb/gs.html](https://signcollect.nl/s3b_glb/gs.html) |
| [signlab_s3b_server](https://github.com/Amsterdam-Humanities-Labs/signlab_s3b_server) | 3 | 3D & assets | SAM3D upload and hand clustering | PHP + Python | core server | experimental | [/s3b_server/top50.html](https://signcollect.nl/s3b_server/top50.html) |
| [signlab_s3b_viewer](https://github.com/Amsterdam-Humanities-Labs/signlab_s3b_viewer) | 3 | 3D & assets | Standalone SAM 3D Body viewer | PHP | core server | experimental | [/s3b_viewer/viewer.html](https://signcollect.nl/s3b_viewer/viewer.html) |
| [signlab_blendAnims](https://github.com/Amsterdam-Humanities-Labs/signlab_blendAnims) | 2 | 3D & assets | `blendBaking` and the avatar site | PHP | core server | production | [avatar.signcollect.nl](https://avatar.signcollect.nl) |
| [signlab_mhr](https://github.com/Amsterdam-Humanities-Labs/signlab_mhr) | 3 | 3D & assets | MHR avatar source assets | — | core server (assets, not a service) | experimental | — |
| [signlab_client_monitor_api](https://github.com/Amsterdam-Humanities-Labs/signlab_client_monitor_api) | 2 | Monitoring | Registration and heartbeat API | PHP + Python | core server | production | `/client_monitor_api/api.php?action=…` |
| [signlab_client_monitor_dashboard](https://github.com/Amsterdam-Humanities-Labs/signlab_client_monitor_dashboard) | 2 | Monitoring | Dashboard over that API | PHP + JS | core server | production | [/client_monitor_dashboard/](https://signcollect.nl/client_monitor_dashboard/) |
| [signlab_demo-media](https://github.com/Amsterdam-Humanities-Labs/signlab_demo-media) | 2 | Deployment | Demo video for seeding a demo host | — | demo hosts | production | — |
| [interface_deploy](interface_deploy) | 2 | Deployment | The deploy toolchain. **Lives in this repo** | Bash + PHP | demo hosts | production | — |

## Where things run

| Server | What it is |
|---|---|
| core server | Production VPS (`cloud`) serving `signcollect.nl`: everything under `/web`, plus `/opt` and `/home/gomer` services such as `pythonCron` |
| Vicon PC | Windows box in the Visualisation Lab. **Runs** `bmcam` and RD_sync; `viconSync` runs on the core server and **pulls from** it |
| DRS | macOS box with the Sony FX30s on USB; runs Sony-SDK and `signlab_drs` |
| demo hosts | Isolated copies built by [install.md](docs/install.md): `dev2` (demo, `/web`), `stijn` (test, `stijn.taila8bdbd.ts.net`, bare Ubuntu 24.04, `--local`), `dev-1` (`/srv/signcollect/web`) |

Full per-machine detail, unit names included: [docs/machines.md](docs/machines.md).
`dev` (100.72.57.25), named in older specs, is offline.

## interface_deploy

[`interface_deploy/`](interface_deploy) is a `git subtree` mirror of a separate
repository. Read it freely; commit changes upstream, because edits made here are
lost on the next sync.
