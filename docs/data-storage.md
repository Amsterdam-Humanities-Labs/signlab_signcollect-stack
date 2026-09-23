# Data storage

Where research data lives when it does not belong in git
([#25](https://github.com/Amsterdam-Humanities-Labs/signlab_signcollect-stack/issues/25)).

| Kind of data | Home |
|---|---|
| Code, config, small fixtures | git |
| Raw and processed studio video, mocap FBX/GLB | research drive (rclone), then LVS |
| Datasets removed from git that are worth keeping | UvA LVS (Large Volume Storage) |
| Derived data meant for reuse or citation | Zenodo, if the owner decides to publish |
| Demo video of identifiable participants | private repo [signlab_demo-media](https://github.com/Amsterdam-Humanities-Labs/signlab_demo-media) |

## Candidates for LVS

Sizes are uncompressed, measured on fresh clones and on the backup bundles of
2026-09-22. "Bundle" means `~/signlab-history-backups/<repo>-2026-09-22.bundle`
on the Mac that ran the history rewrite (#20). That is the only copy.

| Dataset | Where it is now | Size | Personal data | Owner |
|---|---|---|---|---|
| [signlab_patient-info](https://github.com/Amsterdam-Humanities-Labs/signlab_patient-info) pipeline output: `data/` (crawled health pages, PDFs, saved HTML, subtitles, `wordlist.txt`) | removed from `master` in `c84c448`; still on patient-info branch `install-root`; bundle (ref `c84c448^`) | 4,469 files, 297 MB | No. Public health information, third-party copyright | TODO: confirm |
| [signlab_zinnen-annotation](https://github.com/Amsterdam-Humanities-Labs/signlab_zinnen-annotation) database dump and work sheets: `sentences_backup_20260225.sql`, `zinnen_feed.json`, `cache/zinnen_feed.json`, `znn_videos/all_videos.json`, 3 `.xlsx` | bundle only | 8 files, 16.8 MB | Unknown. Check the dump for user names before upload | TODO: confirm |
| zinnen-annotation one-off reports: `deleted_klaar_gloss.json`, `unmatched_sentences.json`, `annotatie_check_userlist.csv` and 7 more | zinnen-annotation branch `install-root` (removed from `main`) | 10 files, 0.9 MB | Pseudonymous (video IDs) | TODO: confirm |
| zinnen-annotation source sentence lists: `2k.csv`, `2k_enhanced.csv`, `zin.csv`, `Extra_2000zinnen.csv`, `extrazinnen_v1.csv`, `lorraine_sentences.csv` | zinnen-annotation `main` (not archived yet; no `archive-19` branch exists) | 6 files, 0.54 MB | No (sentences) | TODO: confirm |
| annotation-tool corrected annotations: `clusters/edit/` (`status.json`, `merge_decisions.json`, `eaf/*.eaf`) | annotation-tool `main`; written at runtime by `io.php` | 40 files, 1.9 MB | Pseudonymous (video IDs) | TODO: confirm |
| [signlab_sam3d-body-queue](https://github.com/Amsterdam-Humanities-Labs/signlab_sam3d-body-queue) hand-cluster plots: `centroids/`, `visualizations/`, `api/cache.json` | bundle only | 29 files, 16.7 MB | No (plots) | TODO: confirm |
| [signlab_drs-pipeline](https://github.com/Amsterdam-Humanities-Labs/signlab_drs-pipeline) DaVinci project: `old/lala6_project.zip` | drs-pipeline `main` | 36.4 MB | Low: 174 recording file paths, no media | TODO: confirm |

The annotation-tool EAFs are live data. Take a snapshot from the core server,
not from git: the server copy may be newer.

## Sensitive: stays out of LVS uploads by this procedure

| Data | Where | Size | Why |
|---|---|---|---|
| `signlab_demo-media` | private GitHub repo | 294 MB | Video of identifiable research participants. Stays a private repo |
| [signlab_background-fix](https://github.com/Amsterdam-Humanities-Labs/signlab_background-fix) previews `tmp/*.mp4`, `tmp/*.png` | bundle only | 20 files, 23.6 MB | Previews of studio recordings, so likely identifiable participants. Derived; the originals are on the research drive |
| zinnen-annotation `znn_videos/test_output/R20251209_1983.mp4` | zinnen-annotation branch `install-root` | 1.5 MB | Same |

Storing participant video anywhere new needs the faculty data steward and the
consent forms first.

## Not research data: do not archive

| File | Size | Get it from |
|---|---|---|
| patient-info `odwn_orbn_gwg-LMF_1.3.xml.gz` | 15.3 MB | Open Dutch WordNet download |
| annotation-tool `clusters/tool/glosses_transformed.json` | 11.0 MB | Signbank export, regenerated |
| zinnen-annotation `MANO_LEFT.pkl`, `MANO_RIGHT.pkl` | 7.6 MB | MANO hand model, from its publisher |
| drs-pipeline `yolov8n.pt` | 6.5 MB | Ultralytics release |
| Sony-SDK `external/**/*.dylib`, [signlab_mocap-postprocessing](https://github.com/Amsterdam-Humanities-Labs/signlab_mocap-postprocessing) `vendor/`, `composer.phar` | 31 MB | Vendor SDK, Composer |

## How to package a dataset

[`scripts/package-for-lvs.sh`](../scripts/package-for-lvs.sh) reads paths from a
clone, bundle or URL at one commit. It writes `MANIFEST.tsv` (path, size,
sha256, source commit), a `README.md` stub and a `.tar.gz`. It uploads nothing.

```sh
scripts/package-for-lvs.sh -r c84c448^ -n signlab_hh-data -o ~/lvs-out \
  ~/signlab-history-backups/signlab_hh-2026-09-22.bundle data
```

Result for patient-info `data/` (tested 2026-09-23): 4,469 files, 297 MB, 111 MB as
`.tar.gz`. One pair of paths differs only in case.
Then: fill in the README stub, upload to LVS, record the LVS path here.
Only after that can the `install-root` copies and the bundle go (#20).
