# Database schema

The database `admin_gebarenoverleg` (MySQL 8.0) on the core server. Source:
[`interface_deploy/db/schema.sql`](../interface_deploy/db/schema.sql), dumped on
2026-09-01. It has 97 tables and 1 view (`hand_pose_similarity_search`), and no rows.

- Relations between tables are a convention only. There are no foreign keys
  between the core tables (`form_data`, `sentences`, `matched_transcriptions`,
  `users`, `labels`, ...). The 13 foreign keys that do exist stay inside side
  modules: `deaftech_*`, `hand_pose_*`,
  `search_*`, `sequence*`, `client_*`, `vicon_files` → `vicon_captures`.
- A diagram of the core tables is in signCollect-v2:
  [docs/architecture/signcollect-architecture.html](https://github.com/Amsterdam-Humanities-Labs/signlab_signCollect-v2/blob/main/docs/architecture/signcollect-architecture.html) (page 06).
- Columns added after the dump are in migrations, mainly in
  `signlab_signCollect-v2/migrations/`. `interface_deploy/scripts/migrate.sh` applies them.

## Tables

Writers and readers were found by searching all 33 repos (main, 2026-09-22)
for `INSERT|UPDATE|DELETE|REPLACE` and `FROM|JOIN <table>`.
- `stack` means `interface_deploy/web_extra/` in this repo.
- Not covered: dynamic table names (except `$table` in signCollect-v2), and
  pythonCron job scripts that were not in git on that date (`/web/helpScripts`,
  `/web/qr`, `/web/josBoard`, `/web/zin/eaf/zin/*.py`). The first three are now
  in signlab_helpScripts, signlab_qr and signlab_josBoard.
- "none found" means no repo has code that uses the table. Ask the owner.

| Table | What it holds | Written by | Read by |
|---|---|---|---|
| `CameraRecords` | Studio camera takes per gloss, camera1-5 file names | studio_beta/save_video_studio.php, stack nmm/mt_cr_sync.php, nmm/emptyVideo.php | studio_beta, zin, studioIndex, hh, client_monitor_dashboard, stack nmm/ |
| `activity_log` | Page visits per user | signCollect-v2/users_api.php | signCollect-v2/php_api/activity_log.php |
| `capture_assignments` | Which user post-processes which capture date | sC-Animation-PP/app/models/Assignment.php | sC-Animation-PP |
| `captures` | Mocap capture register: name, theme, fbx/glb/csv/mp4 flags | mocap/addCaptures.php, getCaptures.php; mocap_lab/save_fbx_studio.php | mocap |
| `chat_history` | Chat messages and responses per session | none found | none found |
| `client_metrics` | CPU, memory, disk samples per monitored client | client_monitor_api/src/ClientMonitorService.php | client_monitor_api |
| `client_monitors` | Registered clients, heartbeat and thresholds | client_monitor_api/src/ClientMonitorService.php | client_monitor_api |
| `csl_glosses` | CSL gloss takes and videos | mocap/updateCSLRecord.php | mocap |
| `deaftech_media` | Deaftech CMS uploaded media | none found | none found |
| `deaftech_page_revisions` | Deaftech CMS page revisions | none found | none found |
| `deaftech_pages` | Deaftech CMS pages | none found | none found |
| `deaftech_sessions` | Deaftech CMS login sessions | none found | none found |
| `deaftech_settings` | Deaftech CMS key/value settings | none found | none found |
| `deaftech_users` | Deaftech CMS users | none found | none found |
| `download_logs` | Animation file downloads per user | sC-Animation-PP/app/controllers/{Upload,Download}Controller.php, public/mark-processed.php | sC-Animation-PP |
| `form_data` | Glosses: the core NGT vocabulary, videos, status | signCollect-v2/php_api/glosses_{create,save,delete}.php, upload_video.php, signbank_sync/, batch_add.php; studio_beta/save_video_studio.php; sCAPI/admin/api.php | sCAPI, signCollect-v2, zin, studio_beta, hh, studioIndex, videoFix, mocapStudio, s3b_glb, sC-Animation-PP, drs, stack |
| `form_submissions` | Search queries submitted via the public form | sCAPI/submit.php | none found |
| `freemocap_data` | FreeMoCap takes per gloss | none found | none found |
| `gloss_notes` | User notes per gloss per dataset | signCollect-v2/php_api/notes_add.php | signCollect-v2 |
| `hand_pose_files` | Hand-pose source files and processing status | none found | view `hand_pose_similarity_search` |
| `hand_pose_finger_distances` | Per-frame finger lengths per hand | none found | view |
| `hand_pose_finger_spreads` | Per-frame finger spread angles per hand | none found | view |
| `hand_pose_fingertip_distances` | Per-frame fingertip-to-fingertip distances | none found | none found |
| `handshapes` | Handshape pool entries with median landmarks | none found | none found |
| `hh_index` | Health-content pages to translate, with status | hh/getZinnen.php, api.php | hh, mocapStudio, studio_beta/hh/ |
| `hh_index_glos` | Glosses linked to an `hh_index` page | hh/api.php | hh, studio_beta/hh/ |
| `hh_lemma` | Lemma → video lookup | none found | hh/api.php |
| `hh_logs` | hh action log | hh/getZinnen.php | hh |
| `hh_segments` | hh video segments and file sizes | hh/segment_api.php | hh |
| `hh_sentences` | Sentence list | none found | hh/api.php |
| `hh_synonyms` | Lemma synonyms for search | none found | sCAPI/src/services/{Search,Suggestion}Service.php |
| `hh_words` | Word → lemma → video lookup | none found | hh, sCAPI |
| `jb_woorden` | Word list with lemma, theme, form_data id | none found | none found |
| `labels` | Gloss labels with colour, per dataset | signCollect-v2/labels_add.php, php_api/labels_create.php | signCollect-v2, zin, studio_beta, sC-Animation-PP, stack |
| `lemmaTable` | Lemma list | zin/updateLemmas.php, migrateLemmas.php, processLemmasWithAI.php | zin |
| `lsm_data` | LSM dataset glosses, same shape as `form_data` | signCollect-v2 (same `$table` files as `form_data`), migrations/2026-05-21-seed-lsm-*.sql | signCollect-v2 |
| `matched_transcriptions` | Recording files ↔ sentence/gloss, transcriptions, post-processing | mocapStudio/update{Tekst,Zin,Bak}Mocap.php; mocapDataPackage/upload.php, batch_process.php; signCollect-v2/php_api/studio_video_*.php, lsm_video_upload.php; zin/getZinnen.php; hh/getZinnen.php; drs/services/qrConvert.py; stack nmm/ | sCAPI, zin, mocapStudio, hh, signCollect-v2, studioIndex, studio_beta, viconDashboard, videoFix, s3b_glb, sC-Animation-PP, drs, client_monitor_dashboard, stack |
| `mocap_data` | Mocap takes per gloss | mocap_lab/saveThree.php, save_fbx_studio.php | mocap |
| `mocap_files` | Mocap takes: LiveLink, Vicon FBX/CSV, video, review | mocap/matchRecords.py, matchVicon.py; mocapDataPackage/upload.php, batch_process.php; mocap_lab/save_fbx_studio.php | mocap, mocap_lab, mocapDataPackage, sCAPI, studio_beta |
| `mocap_recording_logs` | One row per mocap recording started | mocapStudio/logMocapRecording.php | mocapStudio |
| `ngt_data` | NGT gloss takes (same shape as `mocap_data`) | none found | none found |
| `nmm_data` | Non-manual markers per gloss, with theme | stack nmm/update_nmm.php, upload_video_nmm.php, modify_videofile.php; studio_beta/nmm/fetch_nmm_liteGlos.php | sCAPI, studio_beta, studioIndex, hh, s3b_glb, stack |
| `reference_handshapes` | Named reference handshapes with finger metrics | none found | none found |
| `sb_records` | Signbank export: lemmas, senses, phonology | none found | sCAPI/src/services/{Search,Signbank,Video}Service.php |
| `search_cache` | Hand-pose search cache headers | none found | none found |
| `search_cache_results` | Cached hand-pose search results | none found | none found |
| `search_history` | Hand-pose searches run | none found | none found |
| `search_tasks` | Queued hand-pose search jobs | none found | none found |
| `sentences` | Sentences: text, glosses, EAF, annotation status | zin/addZinnen.php, getZinnen.php, getRows.php, syncEafToDatabase.php, resync_video_count.php, *Lemmas*.php; hh/syncEafToDatabase.php; sC-Animation-PP/app/models/MocapFile.php; studio_beta/zin/getRows.php | zin, sCAPI, mocapStudio, viconDashboard, studioIndex, studio_beta, hh, s3b_glb, sC-Animation-PP |
| `sentences_logs` | Sentence edit log | zin/addZinnen.php, getZinnen.php | zin |
| `sequence_items` | Signs in a sequence with frame ranges | none found | none found |
| `sequences` | Named sign sequences per user | none found | none found |
| `studio_data` | Per-day studio file counts per camera | drs/services/qrConvert.py, tools/check_studiofiles.py; studio_beta/fetch_last_capture.php | drs, studio_beta |
| `subtitles` | Subtitle lines per content item | hh/save_subtitle.php | none found |
| `threeGlosses` | Three.js gloss takes (same shape as `mocap_data`) | none found | none found |
| `transcriptions` | File name → transcription text | none found | none found |
| `upload_history` | Hand-pose uploads | none found | none found |
| `users` | Logins, roles, allowed datasets | signCollect-v2/users_api.php; sCAPI/admin/api.php; stack login_sc.php | signCollect-v2, sCAPI, studio_beta, hh, sC-Animation-PP, client_monitor_dashboard, stack |
| `vicon_captures` | Vicon capture sessions: dir, file count, size | viconSync/db_writer.py | viconDashboard, viconSync |
| `vicon_files` | Vicon capture files, status, review | viconSync/db_writer.py, glb_matcher.py; sC-Animation-PP/app/models/MocapFile.php | viconDashboard, viconSync, sC-Animation-PP |
| `vicon_monitor_metadata` | viconSync FTP monitor run totals | viconSync/db_writer.py | none found |
| `videoMetaData` | Video path, time, tags | none found | none found |
| `woordenlijst_approvals` | Word-list approvals and picked videos | none found | none found |
| `word_request_count` | Word request counts per session | none found | none found |
| `zin_api_log` | sCAPI request log | sCAPI/src/services/ApiLogger.php | none found |

## Unused tables: candidates to drop, with the owner's OK

Nothing has been dropped yet. These 32 tables are not used by code in any repo:

- `matched_transcriptions_backup_*` (10): `_20251222`, `_20260106_{111021,111110,111149,112758,113646,114200,144142}`, `_20260112_{095913,095938}`
- `sentences_backup_*` (18): `_20250728_{113520,113601}`, `_20250729_{081049,081103}`, `_before_{csv_import,deletion,duplicate_fix,proper_id_fix,status_update}_2025072*`, `_pre_id_restore_*` (9, 2026-01-06 / 2026-01-12)
- `nmm_data_backup`, `hh_words_old`, `matched_transcriptions_test`, `sentences_temp_proper_fix`

## Regenerating schema.sql

`scripts/dump-schema.sh` runs a read-only `mysqldump --no-data` and strips
`DEFINER` and `AUTO_INCREMENT`. It writes to stdout.

```sh
sudo scripts/dump-schema.sh > schema.sql   # on the database host
```

- Run it again after a migration lands on production, after unused tables are
  dropped, or before you build a new demo host if the last dump is older than
  the newest migration.
- The output replaces `interface_deploy/db/schema.sql`. That file is in the
  subtree, so commit it upstream and then sync.
- Then update the object count in `interface_deploy/scripts/verify.sh`, also
  upstream. It is now 99: 97 tables + 1 view + `schema_migrations`.
