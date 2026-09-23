-- Demo data: 20 real studio recordings copied from production.
--
-- db/schema.sql gives the demo an empty database and db/demo-user.sql gives it
-- one login. With nothing else, every screen renders "0 results" and none of
-- the interface can actually be demonstrated. This is the third seed layer: a
-- small, hand-picked slice of real production data so the tables, the video
-- players, the phonology panel and the sentence tool all have something to
-- show.
--
-- WHY THESE ROWS
--
-- The four tables have no foreign keys; the relationships are conventions the
-- application code enforces, and they were read out of the live queries rather
-- than assumed:
--
--   matched_transcriptions.m_transcription  -> sentences.ID     when zOg='Zin'
--                                           -> form_data.id     when zOg='Glos'
--     (signlab_zinnen-annotation/getZinnen.php fetchVideos/fetchDeletedVideos join on the
--      first; signCollect-v2 php_api/glosses_list.php joins on the second with
--      CAST(mt.m_transcription AS UNSIGNED) = fd.id, and datasets.php pins the
--      zOg values per dataset: extern IS NULL -> mt.zOg='Glos'.)
--
--   CameraRecords.glosId -> the same two targets, again split by CameraRecords.zOg
--     (signlab_zinnen-annotation/getRows.php: "WHERE zOg='Zin' AND glosId = <sentences.ID>";
--      studio_beta/save_video_studio.php writes the row against form_data.id.)
--
-- So a "recording" is a CameraRecords row, and it hangs off either a sentence
-- or a gloss - never both. The 20 are split 10/10 so both halves of the
-- interface have data:
--
--   10 x zOg='Zin'  -> 10 sentences (thema, zinArray, glosses, statuses) and
--                      their matched_transcriptions studio takes. Drives
--                      /zin and the sentence video player.
--   10 x zOg='Glos' -> 10 form_data glosses from the GEBARENSTRAND B set
--                      (animals, food, everyday verbs) with senses, English
--                      glosses, a Signbank id and a filled-in phonology
--                      record, plus one studio take each. Drives /menu_beta.
--
-- Every one of the 20 has a matched_transcriptions row with post_processed=1
-- and both a raw and a post MP4 on disk, so scripts/seed-demo-data.sh has a
-- real file to push for each and the player is never pointed at a 404.
--
-- IDS ARE VERBATIM
--
-- The recording IDs are burnt into the QR code filmed at the start of each
-- take, so the video and the row identify each other by number. Renumbering
-- would break that correspondence silently. Every INSERT therefore carries its
-- production id explicitly and re-running is an update, not a second copy.
--
-- PERSONAL DATA
--
-- These are recordings of identifiable research participants, so only the
-- columns the demo actually needs are copied. Deliberately NOT copied:
--
--   form_data.logboek          per-gloss audit trail, names staff in prose
--                              ("Glos bijgewerkt door: <first name>")
--   form_data.wie,             JSON arrays of staff user ids - owner,
--     madeByWie,               maker, recordist, and who flagged the gloss
--     studioOpnameWie,         for checking. Meaningless here (the demo has
--     wie_snel_opname,         one user) and needlessly identifying.
--     control_nodig
--   form_data.zelfopname,      references to participants' self-recorded
--     process_zelfopname,      phone videos. Those files are not copied, and
--     videoTop, videoLeft,     the rows would only point at 404s.
--     videoCenter, videoRight,
--     videoA, videoB
--   sentences.userId           replaced below with the demo account
--   CameraRecords.user         replaced below with the demo account
--
-- Also skipped: workflow bookkeeping that means nothing off production
-- (wanneer, actie, entry, gbc, captureStartTime, unreal_take, synced,
-- processed, tyd_app_ready, signbank_opname, OpnameThreeD, glosVeranderen,
-- linkSignbank).
--
-- Regenerate with the extraction described in scripts/seed-demo-data.sh.

-- Rows that referenced a real member of staff point at the demo login instead.
-- NULL if demo-user.sql has not run yet, which is harmless: neither column is
-- displayed by the pages these rows feed.
SET @demo_user := (SELECT `userId` FROM `users` WHERE `user` = 'gomer' LIMIT 1);

-- 10 glosses. Parents of the zOg='Glos' recordings.
INSERT INTO `form_data`
  (`id`,`glos`,`glos_engels`,`senses`,`sensesEngels`,`thema`,`labels`,`glosZichtbaar`,`extern`,`signbank`,`signbank_status`,`fonologie_fase1`,`fonologie_fase2`,`handvorm`,`Handeness`,`strongHand`,`weakHand`,`handLocation`,`HandshapeChange`,`RelationArticulators`,`relOrientationMove`,`relOrientationLoc`,`orientationChange`,`ContactType`,`MovementShape`,`MovementDirection`,`RepeatedMovement`,`AlternatingMovement`,`relativeOrienationMovement`,`relativeOrienationLocation`,`virtualObjectt`,`phonologyOther`,`mouthGesture`,`mouthing`,`phoneticVariation`,`morfologie`,`werkwoord`,`origin`,`woord`,`glosStatus`)
VALUES
('87','FRUIT-A','FRUIT-A','["fruit"]','["fruit"]','GEBARENSTRAND B',NULL,'0',NULL,'46154',NULL,'1',NULL,NULL,'1','C_spread',NULL,'Cheek',NULL,NULL,NULL,NULL,NULL,NULL,'Circle',NULL,'True','False','Finger tips',NULL,NULL,NULL,NULL,NULL,NULL,'[]',NULL,'UvA',NULL,''),
('108','HONING-B','HONEY-B','["honing"]','["honey"]','GEBARENSTRAND B',NULL,'0',NULL,'46165',NULL,'1',NULL,NULL,'2a','Money','C','Neutral space',NULL,NULL,NULL,NULL,'Rotation',NULL,NULL,'Upwards','False','False','Base',NULL,NULL,NULL,NULL,NULL,'One-handed','[]',NULL,'UvA',NULL,''),
('437','PANNENKOEK-B','PANCAKE-B','["pannenkoek"]','["pancake"]','GEBARENSTRAND B',NULL,'0',NULL,'47294',NULL,'1',NULL,NULL,'1','B',NULL,'Neutral space',NULL,NULL,NULL,NULL,'Flexion',NULL,NULL,'Backwards + upwards','False','False','Palm',NULL,NULL,NULL,NULL,NULL,NULL,'[]',NULL,'UvA',NULL,''),
('1072','KABOUTER-A','GNOME-A','["kabouter, dwerg", "lanzarote"]','["gnome", "Lanzarote"]','GEBARENSTRAND B',NULL,'0',NULL,'48283',NULL,'1','0',NULL,'1','C_spread',NULL,'Head','Closing',NULL,NULL,NULL,'Ulnar flexion','Initial','Arc','Downwards','False','False','Ulnar','Radial',NULL,NULL,NULL,NULL,NULL,'[]',NULL,'UvA',NULL,''),
('1602','GEZELLIG-A','COSY-A','["gezellig"]','["enjoyable, cosy, pleasant"]','GEBARENSTRAND B',NULL,'0',NULL,'48720',NULL,'1','1',NULL,'2s','T',NULL,'Chest',NULL,'Next-to',NULL,NULL,'Supination','Brush','Arc','Backwards + upwards','False','False',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'[]',NULL,'UvA',NULL,''),
('1711','BEVER','BEAVER','["bever"]','["beaver"]','GEBARENSTRAND B',NULL,'0',NULL,'45695',NULL,'1',NULL,NULL,'1','B',NULL,'Neutral space',NULL,NULL,NULL,NULL,'Flexion',NULL,NULL,NULL,'False','False',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'[]',NULL,'UvA',NULL,''),
('1721','DOLFIJN','DOLPHIN','["dolfijn"]','["dolphin"]','GEBARENSTRAND B',NULL,'0',NULL,'45747',NULL,'1',NULL,NULL,'1','B',NULL,'Neutral space',NULL,NULL,NULL,NULL,NULL,NULL,'Arc','Contralateral','False','False','Finger tips',NULL,NULL,NULL,NULL,NULL,NULL,'[]',NULL,'UvA',NULL,''),
('1722','EEKHOORN','SQUIRREL','["eekhoorn"]','["Squirrel"]','GEBARENSTRAND B',NULL,'0',NULL,'45740',NULL,'1',NULL,NULL,'2s','V_curved','V_curved','Neutral space',NULL,NULL,NULL,NULL,NULL,'Final',NULL,'Contralateral','False','False',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'[]',NULL,'UvA',NULL,''),
('1725','EGEL-A','HEDGEHOG-A','["egel"]','["Hedgehog"]','GEBARENSTRAND B',NULL,'0',NULL,'45746',NULL,'1',NULL,NULL,'2a','S','S','Weak hand: thumb side','Opening',NULL,NULL,NULL,'Ulnar flexion','Continuous',NULL,NULL,'False','False',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'[]',NULL,'UvA',NULL,''),
('8580','GIETEN','POUR','["gieten", "kan, ketel", "benzine"]','["pour", "jug, pitcher, kettle", "petrol"]','GEBARENSTRAND B',NULL,'0',NULL,'47086',NULL,'1','1',NULL,'1','L',NULL,'Neutral space',NULL,NULL,NULL,NULL,NULL,NULL,'Arc','Downwards','False','False','Finger tips',NULL,NULL,NULL,NULL,NULL,NULL,'[]',NULL,'UvA',NULL,'')

ON DUPLICATE KEY UPDATE
  `glos` = VALUES(`glos`),
  `glos_engels` = VALUES(`glos_engels`),
  `senses` = VALUES(`senses`),
  `sensesEngels` = VALUES(`sensesEngels`),
  `thema` = VALUES(`thema`),
  `labels` = VALUES(`labels`),
  `glosZichtbaar` = VALUES(`glosZichtbaar`),
  `extern` = VALUES(`extern`),
  `signbank` = VALUES(`signbank`),
  `signbank_status` = VALUES(`signbank_status`),
  `fonologie_fase1` = VALUES(`fonologie_fase1`),
  `fonologie_fase2` = VALUES(`fonologie_fase2`),
  `handvorm` = VALUES(`handvorm`),
  `Handeness` = VALUES(`Handeness`),
  `strongHand` = VALUES(`strongHand`),
  `weakHand` = VALUES(`weakHand`),
  `handLocation` = VALUES(`handLocation`),
  `HandshapeChange` = VALUES(`HandshapeChange`),
  `RelationArticulators` = VALUES(`RelationArticulators`),
  `relOrientationMove` = VALUES(`relOrientationMove`),
  `relOrientationLoc` = VALUES(`relOrientationLoc`),
  `orientationChange` = VALUES(`orientationChange`),
  `ContactType` = VALUES(`ContactType`),
  `MovementShape` = VALUES(`MovementShape`),
  `MovementDirection` = VALUES(`MovementDirection`),
  `RepeatedMovement` = VALUES(`RepeatedMovement`),
  `AlternatingMovement` = VALUES(`AlternatingMovement`),
  `relativeOrienationMovement` = VALUES(`relativeOrienationMovement`),
  `relativeOrienationLocation` = VALUES(`relativeOrienationLocation`),
  `virtualObjectt` = VALUES(`virtualObjectt`),
  `phonologyOther` = VALUES(`phonologyOther`),
  `mouthGesture` = VALUES(`mouthGesture`),
  `mouthing` = VALUES(`mouthing`),
  `phoneticVariation` = VALUES(`phoneticVariation`),
  `morfologie` = VALUES(`morfologie`),
  `werkwoord` = VALUES(`werkwoord`),
  `origin` = VALUES(`origin`),
  `woord` = VALUES(`woord`),
  `glosStatus` = VALUES(`glosStatus`);

-- 10 sentences. Parents of the zOg='Zin' recordings. video_count is a
-- cache signlab_zinnen-annotation keeps in sync itself; seeded as 1 because exactly one
-- matched_transcriptions take per sentence is copied.
INSERT INTO `sentences`
  (`ID`,`zinID`,`glosArray`,`enabled`,`zinArray`,`thema`,`sortArray`,`comments`,`status_annotatie`,`status_glos`,`status_video`,`mcp_status_postprocessing`,`mcp_status_tijd_annotatie`,`mcp_status_tijd_annotatie_gvg`,`zinString`,`zinStringEAF`,`glosses`,`lemmaList`,`search_lemma`,`gvg`,`label`,`ai_Occurences`,`lemma_processed`,`lemma_processed_at`,`lemma_error`,`eaf_synced_at`,`eaf_sync_status`,`eaf_sync_error`,`status_gvg`,`videoTop`, `userId`, `video_count`)
VALUES
('1',NULL,'["", "", "", "", ""]',NULL,'["Doe", "je", "je", "jas", "aan?"]','Aankleden',NULL,'-','Klaar','Klaar','Klaar',NULL,NULL,NULL,'Doe je je jas aan?','Doe je jas maar aan.','["PT-1hand","JAS-A","JAS-A","PT-1hand"]','["doen", "je", "je", "jas", "aan"]',NULL,'["jij", "jas", "(jas) aandoen", "jij"]','ZNN','{"words": ["aanhebben", {"word": "AANDOEN kleding", "added_at": "2025-06-15 12:17:20", "confidence": 95}, {"word": "aanhebben (kleding)", "added_at": "2025-06-15 12:18:07", "confidence": 95}, {"word": "AANHEBBEN kleding", "added_at": "2025-06-15 12:18:48", "confidence": 95}, {"word": "AAN(DOEN)", "added_at": "2025-06-15 12:26:05", "confidence": 100, "batch_processed": true}, {"word": "aandoen (kleding)", "added_at": "2025-06-15 12:26:07", "confidence": 100, "batch_processed": true}, {"word": "AANKLEDEN", "added_at": "2025-06-15 13:17:04", "confidence": 60, "batch_processed": true}, {"word": "JAS", "added_at": "2025-06-15 13:57:51", "confidence": 95, "batch_processed": true}, {"word": "JAS aandoen", "added_at": "2025-06-15 13:57:51", "confidence": 95, "batch_processed": true}, {"word": "jas/jack", "added_at": "2025-06-15 13:57:51", "confidence": 95, "batch_processed": true}, {"word": "EN", "added_at": "2025-06-15 16:36:15", "confidence": 60, "batch_processed": true}, {"word": "eventjes", "added_at": "2025-06-15 17:05:12", "confidence": 40, "batch_processed": true}, {"word": "doen", "added_at": "2025-06-15 18:03:09", "confidence": 95, "batch_processed": true}, {"word": "uitdoen (kleding)", "added_at": "2025-06-15 23:37:28", "confidence": 60, "batch_processed": true}, {"word": "NU", "added_at": "2025-06-16 07:57:21", "confidence": 60, "batch_processed": true}], "last_updated": "2025-06-16 07:57:21.000000"}','1',NULL,NULL,'2026-04-30 12:37:53','synced',NULL,'Klaar',NULL,@demo_user,1),
('846',NULL,'["", "", "", "", "", ""]',NULL,'["Heb", "je", "zin", "in", "je", "fles?"]','Familie en personen',NULL,'','Klaar','Klaar','Klaar','1',NULL,NULL,'Heb je zin in je fles?','Heb je zin in je fles?','["PT-1hand","GLAS-B","ZIN-IN-A","PT-1hand"]','["heb", "je", "zin", "in", "je", "fles"]',NULL,'["jouw", "fles", "zin in", "fles", "jij"]','ZNN','{"words": [{"word": "zin-hebben", "added_at": "2025-06-16 02:17:39", "confidence": 95, "batch_processed": true}], "last_updated": "2025-06-16 02:17:39.000000"}','1','2025-06-28 16:48:05',NULL,'2026-04-30 15:45:44','synced',NULL,'Klaar',NULL,@demo_user,1),
('870',NULL,'["", "", "", "", "", "", ""]',NULL,'["De", "kapper", "kan", "wel", "goed", "knippen,", "hè?"]','kapper',NULL,'-','Klaar','Klaar','Klaar',NULL,NULL,NULL,'De kapper kan wel goed knippen, hè?','De kapper kan goed knippen, hè?','["PT-1hand","nvt","PERSOON-A","TALENT-B","nvt","JA-A"]','["de", "kapper", "kunnen", "wel", "goed", "knippen", "hè"]',NULL,'[]','ZNN','{"words": [{"word": "GOED", "added_at": "2025-06-15 13:08:44", "confidence": 100, "batch_processed": true}, {"word": "KAN", "added_at": "2025-06-15 14:01:51", "confidence": 90, "batch_processed": true}, {"word": "KAPPER", "added_at": "2025-06-15 14:03:10", "confidence": 100, "batch_processed": true}, {"word": "KAN niet", "added_at": "2025-06-15 19:14:15", "confidence": 50, "batch_processed": true}, {"word": "goed", "added_at": "2025-06-16 06:14:22", "confidence": 100, "batch_processed": true}], "last_updated": "2025-06-16 06:14:22.000000"}','1','2025-06-28 16:50:12',NULL,'2026-04-30 15:49:28','synced',NULL,'Klaar',NULL,@demo_user,1),
('960',NULL,'["", "", "", "", "", ""]',NULL,'["je", "moest", "wel", "nodig", "plassen", "hè?"]','Naar de wc',NULL,'Opnieuw','Niet Klaar','Niet Klaar','Niet Klaar',NULL,NULL,NULL,'je moest wel nodig plassen hè?','','["LAAT-MAAR-B","ECHT-A","GEBRUIKEN-A","PLASSEN-B","WELKE-A","PT-1HAND"]','["je", "moest", "wel", "nodig", "plas", "hè"]',NULL,'[]','ZNN','{"words": [{"word": "BROEK", "added_at": "2025-06-15 12:43:27", "confidence": 60, "batch_processed": true}, {"word": "echt/echt-waar…", "added_at": "2025-06-15 12:58:06", "confidence": 60, "batch_processed": true}, {"word": "ECHT", "added_at": "2025-06-15 13:29:34", "confidence": 65, "batch_processed": true}, {"word": "PLAS", "added_at": "2025-06-15 22:00:52", "confidence": 95, "batch_processed": true}, {"word": "Plas/Plassen", "added_at": "2025-06-15 22:01:02", "confidence": 100, "batch_processed": true}, {"word": "PLASSEN", "added_at": "2025-06-15 22:01:11", "confidence": 100, "batch_processed": true}, {"word": "WC", "added_at": "2025-06-16 01:27:35", "confidence": 60, "batch_processed": true}], "last_updated": "2025-06-16 01:27:35.000000"}','1','2025-06-28 16:58:28',NULL,'2026-06-11 19:24:03','synced',NULL,'Niet Klaar',NULL,@demo_user,1),
('1926',NULL,'["", "", "", "", "", "", "", "", ""]',NULL,'["Zal", "ik", "kijken", "wat", "voor", "weer", "het", "wordt", "vandaag?"]','weer',NULL,'','Klaar','Klaar','Klaar','1','Klaar',NULL,'Zal ik kijken wat voor weer het wordt vandaag?','Zal ik kijken wat voor weer het wordt vandaag?','["VANDAAG","WEER","HOE-B","PO","PT-1hand:1","KIJKEN-F","PT-1hand:1"]','["zal", "ik", "kijken", "wat", "voor", "weer", "het", "wordt", "vandaag"]',NULL,'["vandaag", "weer", "hoe", "(algemeen vraaggebaar)", "ik", "kijken", "ik"]','ZNN','{"words": [{"word": "Kijken", "added_at": "2025-06-16 00:26:05", "confidence": 100, "batch_processed": true}, {"word": "weer (het)", "added_at": "2025-06-16 01:31:50", "confidence": 100, "batch_processed": true}, {"word": "WEER", "added_at": "2025-06-16 01:40:19", "confidence": 100, "batch_processed": true}, {"word": "ZONNIG WEER", "added_at": "2025-06-16 01:40:26", "confidence": 60, "batch_processed": true}], "last_updated": "2025-06-16 01:40:26.000000"}','1','2025-06-28 18:28:55',NULL,'2026-05-18 13:45:11','synced',NULL,'Klaar',NULL,@demo_user,1),
('2024',NULL,'["", "", "", "", "", "", ""]',NULL,'["Je", "moet", "nog", "even", "je", "druppels", "nemen."]','Overig',NULL,'Opnieuw, druppels altijd locatieve gebaar, dus in mond, in oog of in oor','Niet Klaar','Niet Klaar','Niet Klaar',NULL,NULL,NULL,'Je moet nog even je druppels nemen.','','[]','["je", "moet", "nog", "even", "je", "druppel", "nemen"]',NULL,'[]','ZNN','{"words": [{"word": "DRUPPELS", "added_at": "2025-06-15 12:55:48", "confidence": 100, "batch_processed": true}, {"word": "GROOT klein voorwerp", "added_at": "2025-06-15 17:27:15", "confidence": 70, "batch_processed": true}, {"word": "doen", "added_at": "2025-06-15 18:03:19", "confidence": 40, "batch_processed": true}, {"word": "Weinig/beetje", "added_at": "2025-06-16 01:42:15", "confidence": 70, "batch_processed": true}], "last_updated": "2025-06-16 01:42:15.000000"}','1','2025-06-28 18:38:28',NULL,'2026-06-11 19:24:28','synced',NULL,'Niet Klaar','M20241216_1307.mp4',@demo_user,1),
('4211',NULL,'["", "", "", ""]',NULL,'["De", "pasta", "is", "warm."]','Eten en drinken',NULL,'','Klaar','Klaar','Klaar','1','Klaar',NULL,'De pasta is warm.','De pasta is warm.','["PASTA-B","PT-1hand","WARM-A","PT-1hand"]','["de", "pasta", "zijn", "warm"]',NULL,'["pasta", "IX", "warm", "IX"]','ZNN','{"words": [{"word": "HEET", "added_at": "2025-06-15 13:46:19", "confidence": 70, "batch_processed": true}, {"word": "dan/daarna", "added_at": "2025-06-15 15:44:42", "confidence": 50, "batch_processed": true}, {"word": "ETEN", "added_at": "2025-06-15 16:38:10", "confidence": 65, "batch_processed": true}, {"word": "PASTA", "added_at": "2025-06-15 21:54:29", "confidence": 100, "batch_processed": true}, {"word": "WARM", "added_at": "2025-06-16 01:21:57", "confidence": 100, "batch_processed": true}, {"word": "ZN", "added_at": "2025-06-16 02:13:33", "confidence": 95, "batch_processed": true}, {"word": "goed", "added_at": "2025-06-16 06:14:32", "confidence": 40, "batch_processed": true}, {"word": "zijn", "added_at": "2025-06-16 07:21:10", "confidence": 85, "batch_processed": true}, {"word": "MAALTIJD", "added_at": "2025-06-16 07:24:13", "confidence": 80, "batch_processed": true}], "last_updated": "2025-06-16 07:24:13.000000"}','1','2025-06-28 16:38:43',NULL,'2026-05-18 12:23:12','synced',NULL,'Klaar',NULL,@demo_user,1),
('4212',NULL,'["", "", "", ""]',NULL,'["Heb", "je", "genoeg", "gegeten?"]','eten en drinken',NULL,'','Klaar','Klaar','Klaar',NULL,NULL,NULL,'Heb je genoeg gegeten?','Heb je genoeg gegeten?','["PT-1hand","VOL-ZITTEN-A","ETEN-A","PT-1hand"]','["heb", "je", "genoeg", "eten"]',NULL,'["jij", "genoeg", "eten", "jij"]','ZNN','{"words": [{"word": "Erg-veel-eten", "added_at": "2025-06-15 13:00:52", "confidence": 80, "batch_processed": true}, {"word": "GENOEG", "added_at": "2025-06-15 13:37:24", "confidence": 95, "batch_processed": true}, {"word": "dan/daarna", "added_at": "2025-06-15 15:44:41", "confidence": 50, "batch_processed": true}, {"word": "ETEN", "added_at": "2025-06-15 16:38:10", "confidence": 95, "batch_processed": true}, {"word": "HEBBEN", "added_at": "2025-06-15 18:32:44", "confidence": 95, "batch_processed": true}, {"word": "goed", "added_at": "2025-06-16 06:14:21", "confidence": 60, "batch_processed": true}, {"word": "MAALTIJD", "added_at": "2025-06-16 07:24:13", "confidence": 90, "batch_processed": true}], "last_updated": "2025-06-16 07:24:13.000000"}','1','2025-06-28 16:38:59',NULL,'2026-05-18 12:22:07','synced',NULL,'Klaar',NULL,@demo_user,1),
('4216',NULL,'["", "", "", ""]',NULL,'["Wat", "wil", "je", "bestellen?"]','restaurant',NULL,'','Klaar','Klaar','Klaar',NULL,NULL,NULL,'Wat wil je bestellen?','Wat wil je bestellen?','["WAT-A","BESTELLEN-A","WILLEN-A","PT-1hand"]','["wat", "willen", "je", "bestellen"]',NULL,'["wat", "bestellen", "willen", "jij"]','ZNN','{"words": [{"word": "dan/daarna", "added_at": "2025-06-15 15:44:41", "confidence": 55, "batch_processed": true}, {"word": "goed", "added_at": "2025-06-16 06:14:32", "confidence": 40, "batch_processed": true}, {"word": "MAALTIJD", "added_at": "2025-06-16 07:24:18", "confidence": 80, "batch_processed": true}], "last_updated": "2025-06-16 07:24:18.000000"}','1','2025-06-28 18:41:07',NULL,'2026-05-18 12:21:02','synced',NULL,'Klaar',NULL,@demo_user,1),
('4217',NULL,'["", "", "", "", ""]',NULL,'["we", "kunnen", "niet", "alles", "doorspoelen"]','tv kijken',NULL,'','Klaar','Klaar','Klaar',NULL,NULL,NULL,'we kunnen niet alles doorspoelen','We kunnen niet alles doorspoelen.','["TWEEEN-F","ALLES-D","VASTHOUDEN-K","PIJL","KUNNEN-NIET-D","PO+PT"]','["we", "kunnen", "niet", "alles", "doorspoelen"]',NULL,'["wij (jij en ik)", "alles", "doorspoelen (op tv)", "niet kunnen"]','ZNN','{"words": [{"word": "GEEN", "added_at": "2025-06-15 13:37:10", "confidence": 90, "batch_processed": true}, {"word": "KAN", "added_at": "2025-06-15 14:01:51", "confidence": 90, "batch_processed": true}, {"word": "dan/daarna", "added_at": "2025-06-15 15:44:41", "confidence": 55, "batch_processed": true}, {"word": "EN", "added_at": "2025-06-15 16:36:28", "confidence": 60, "batch_processed": true}, {"word": "KAN niet", "added_at": "2025-06-15 19:14:14", "confidence": 90, "batch_processed": true}, {"word": "NIET", "added_at": "2025-06-15 21:11:54", "confidence": 100, "batch_processed": true}, {"word": "niet/geen", "added_at": "2025-06-15 21:12:23", "confidence": 100, "batch_processed": true}, {"word": "Televisie/tv", "added_at": "2025-06-15 23:12:54", "confidence": 65, "batch_processed": true}, {"word": "wij-allemaal", "added_at": "2025-06-16 01:49:23", "confidence": 85, "batch_processed": true}, {"word": "UIT(DOEN)", "added_at": "2025-06-16 09:56:50", "confidence": 50, "batch_processed": true}], "last_updated": "2025-06-16 09:56:50.000000"}','1','2025-06-28 18:41:11',NULL,'2026-05-18 12:19:45','synced',NULL,'Klaar',NULL,@demo_user,1)

ON DUPLICATE KEY UPDATE
  `zinID` = VALUES(`zinID`),
  `glosArray` = VALUES(`glosArray`),
  `enabled` = VALUES(`enabled`),
  `zinArray` = VALUES(`zinArray`),
  `thema` = VALUES(`thema`),
  `sortArray` = VALUES(`sortArray`),
  `comments` = VALUES(`comments`),
  `status_annotatie` = VALUES(`status_annotatie`),
  `status_glos` = VALUES(`status_glos`),
  `status_video` = VALUES(`status_video`),
  `mcp_status_postprocessing` = VALUES(`mcp_status_postprocessing`),
  `mcp_status_tijd_annotatie` = VALUES(`mcp_status_tijd_annotatie`),
  `mcp_status_tijd_annotatie_gvg` = VALUES(`mcp_status_tijd_annotatie_gvg`),
  `zinString` = VALUES(`zinString`),
  `zinStringEAF` = VALUES(`zinStringEAF`),
  `glosses` = VALUES(`glosses`),
  `lemmaList` = VALUES(`lemmaList`),
  `search_lemma` = VALUES(`search_lemma`),
  `gvg` = VALUES(`gvg`),
  `label` = VALUES(`label`),
  `ai_Occurences` = VALUES(`ai_Occurences`),
  `lemma_processed` = VALUES(`lemma_processed`),
  `lemma_processed_at` = VALUES(`lemma_processed_at`),
  `lemma_error` = VALUES(`lemma_error`),
  `eaf_synced_at` = VALUES(`eaf_synced_at`),
  `eaf_sync_status` = VALUES(`eaf_sync_status`),
  `eaf_sync_error` = VALUES(`eaf_sync_error`),
  `status_gvg` = VALUES(`status_gvg`),
  `videoTop` = VALUES(`videoTop`),
  `userId` = VALUES(`userId`),
  `video_count` = VALUES(`video_count`);

-- 20 studio takes, one per recording. m_file names the MP4 that
-- scripts/seed-demo-data.sh pushes: <stem>.mp4 under
-- /web/gebarenoverleg_media/studioFilesMini/{raw,post}/.
INSERT INTO `matched_transcriptions`
  (`id`,`l_file`,`m_file`,`r_file`,`l_transcription`,`m_transcription`,`r_transcription`,`definitive_outcome`,`added`,`a_file`,`b_file`,`a_transcription`,`b_transcription`,`videoCategory`,`videoLabel`,`zOg`,`videoTop`,`post_processed`,`signbank_upload`,`time`,`date`,`format`,`tyd_converted`,`rendered`,`converted`,`render_date`,`convert_date`,`thumbnail`,`thumbnail_date`,`tyd_rendered`,`tyd_thumbnail`,`app_ready`,`has_mocap`,`has_sam`)
VALUES
('1619','L20240418_0020.wav','M20240418_0020.wav','R20240418_0020.wav','437','437','437','437','1',NULL,NULL,NULL,NULL,NULL,NULL,'Glos','','1',NULL,NULL,'',NULL,NULL,NULL,'1',NULL,'2025-04-30',NULL,NULL,NULL,NULL,'0',NULL,'0'),
('3099','L20240612_0015.wav','M20240612_0015.wav','R20240612_0015.wav','108','108','108','108','1',NULL,NULL,NULL,NULL,NULL,NULL,'Glos','225d30c035095a6c7ae5e9a9d31cefca3dcba25a65e15b1152ae8f2bc6f0c0cf.webm','1',NULL,NULL,'',NULL,NULL,NULL,'1',NULL,'2025-04-30',NULL,NULL,NULL,NULL,'0',NULL,'0'),
('3369','L20240603_0118.wav','M20240603_0118.wav','R20240603_0118.wav','1072','1072','1072','1072','1',NULL,NULL,NULL,NULL,NULL,NULL,'Glos','1413d8720256c5d14f02e1768111815aed2ed97b2f0f231ed06d8d55023645fc.webm','1',NULL,NULL,'',NULL,NULL,NULL,'1',NULL,'2025-04-30',NULL,NULL,NULL,NULL,'0',NULL,'0'),
('3528','L20240513_0089.wav','M20240513_0089.wav','R20240513_0089.wav','1602','1602','1602','1602','1',NULL,NULL,NULL,NULL,NULL,NULL,'Glos','ea46e2ea55b2e8203c463783ae6f40f460a2f1150976a21661cd0c11e99631f8.webm.webm','1',NULL,NULL,'',NULL,NULL,NULL,'1',NULL,'2025-04-30',NULL,NULL,NULL,NULL,'0',NULL,'0'),
('3577','L20240507_0012.wav','M20240507_0012.wav','R20240507_0012.wav','1721','1721','1721','1721','1',NULL,NULL,NULL,NULL,NULL,NULL,'Glos','2b4bf85433ed633e2f8c439fefd2c5fc7942e9f121caa905b11236f866dbbfee.webm','1',NULL,NULL,'',NULL,NULL,NULL,'1',NULL,'2025-04-30',NULL,NULL,NULL,NULL,'0',NULL,'0'),
('3578','L20240507_0014.wav','M20240507_0014.wav','R20240507_0014.wav','1722','1722','1722','1722','1',NULL,NULL,NULL,NULL,NULL,NULL,'Glos','0884506b4476f235c22de4579aec17ea4099dc2dcb1ca9bea040f9abef0c2825.webm.webm','1',NULL,NULL,'',NULL,NULL,NULL,'1',NULL,'2025-04-30',NULL,NULL,NULL,NULL,'0',NULL,'0'),
('3581','L20240507_0015.wav','M20240507_0015.wav','R20240507_0015.wav','1725','1725','1725','1725','1',NULL,NULL,NULL,NULL,NULL,NULL,'Glos','0eac2ac6cddf786eb6f144090c2191f302f6ca1dc31679d879d2bb4e87a327d7.webm','1',NULL,NULL,'',NULL,NULL,NULL,'1',NULL,'2025-04-30',NULL,NULL,NULL,NULL,'0',NULL,'0'),
('4127','L20240910_0598.wav','M20240910_0598.wav','R20240910_0598.wav','87','87','87','87','1','A20240910_0597.wav','B20240910_0598.wav','87','87',NULL,NULL,'Glos',NULL,'1',NULL,NULL,'',NULL,NULL,NULL,'1',NULL,'2025-04-30',NULL,NULL,NULL,NULL,'0',NULL,'0'),
('4499','L20240913_0969.wav','M20240913_0969.wav','R20240913_0969.wav','8580','8580','8580','8580','1','A20240913_0968.wav','B20240913_0867.wav','8580','8580',NULL,NULL,'Glos',NULL,'1',NULL,NULL,'',NULL,NULL,NULL,'1',NULL,'2025-04-30',NULL,NULL,NULL,NULL,'0',NULL,'0'),
('19770','L20241218_2776.wav','M20241218_1689.wav','R20241218_5400.wav','1711','1711','1711','1711','1','A20241218_4650.wav','B20241218_3893.wav','1711','1711',NULL,NULL,'glos',NULL,'1',NULL,'17:14:16','2024-12-18',NULL,NULL,NULL,'1',NULL,'2025-04-30',NULL,NULL,NULL,NULL,'0',NULL,'0'),
('52647','L20260126_3146.wav','M20260126_1567.wav','R20260126_5787.wav','4211','4211','4211','4211','1','A20260126_4607.wav','B20260126_3989.wav','4211','4211',NULL,NULL,'zin',NULL,'1',NULL,'11:20:03','2026-01-26',NULL,NULL,NULL,NULL,NULL,NULL,'1','2026-02-23',NULL,NULL,'0','1',NULL),
('52662','L20260126_3148.wav','M20260126_1569.wav','R20260126_5789.wav','4212','4212','4212','4212','1','A20260126_4609.wav','B20260126_3991.wav','4212','4212',NULL,NULL,'zin',NULL,'1',NULL,'11:20:37','2026-01-26',NULL,NULL,NULL,NULL,NULL,NULL,'1','2026-02-23',NULL,NULL,'0','1',NULL),
('53210','L20260127_3621.wav','M20260127_2042.wav','R20260127_6262.wav','4216','4216','4216','4216','1','A20260127_5082.wav','B20260127_4459.wav','4216','4216',NULL,NULL,'zin',NULL,'1',NULL,'11:04:34','2026-01-27',NULL,NULL,NULL,NULL,NULL,NULL,'1','2026-02-22',NULL,NULL,'0','1',NULL),
('53307','L20260127_3791.wav','M20260127_2212.wav','R20260127_6432.wav','4217','4217','4217','4217','1','A20260127_5252.wav','B20260127_4629.wav','4217','4217',NULL,NULL,'zin',NULL,'1',NULL,'14:44:55','2026-01-27',NULL,NULL,NULL,NULL,NULL,NULL,'1','2026-02-21',NULL,NULL,'0','1',NULL),
('56798','L20260224_7009.wav','M20260224_5425.wav','R20260224_9647.wav','1','1','1','1','1','A20260224_8481.wav','B20260224_7842.wav','1','1',NULL,NULL,'zin',NULL,'1',NULL,'15:20:21','2026-02-24',NULL,NULL,NULL,NULL,NULL,NULL,'1','2026-02-25',NULL,NULL,'0','1',NULL),
('56902','L20260224_7025.wav','M20260224_5441.wav','R20260224_9663.wav','1926','1926','1926','1926','1','A20260224_8497.wav','B20260224_7858.wav','1926','1926',NULL,NULL,'zin',NULL,'1',NULL,'15:32:35','2026-02-24',NULL,NULL,NULL,NULL,NULL,NULL,'1','2026-02-26',NULL,NULL,'0','1',NULL),
('57063','L20260227_7534.wav','M20260227_5950.wav','R20260227_0173.wav','2024','2024','2024','2024','1','A20260227_9006.wav','B20260227_8367.wav','2024','2024',NULL,NULL,'zin',NULL,'1',NULL,'14:33:13','2026-02-27',NULL,NULL,NULL,NULL,NULL,NULL,'1','2026-02-28',NULL,NULL,'0',NULL,NULL),
('57068','L20260227_7539.wav','M20260227_5955.wav','R20260227_0178.wav','846','846','846','846','1','A20260227_9011.wav','B20260227_8372.wav','846','846',NULL,NULL,'zin',NULL,'1',NULL,'14:38:35','2026-02-27',NULL,NULL,NULL,NULL,NULL,NULL,'1','2026-02-28',NULL,NULL,'0','1',NULL),
('57349','L20260227_7582.wav','M20260227_5998.wav','R20260227_0221.wav','870','870','870','870','1','A20260227_9054.wav','B20260227_8415.wav','870','870',NULL,NULL,'zin',NULL,'1',NULL,'15:35:00','2026-02-27',NULL,NULL,NULL,NULL,NULL,NULL,'1','2026-02-28',NULL,NULL,'0','1',NULL),
('57376','L20260227_7565.wav','M20260227_5981.wav','R20260227_0204.wav','960','960','960','960','1','A20260227_9037.wav','B20260227_8398.wav','960','960',NULL,NULL,'zin',NULL,'1',NULL,'15:18:22','2026-02-27',NULL,NULL,NULL,NULL,NULL,NULL,'1','2026-02-28',NULL,NULL,'0',NULL,NULL)

ON DUPLICATE KEY UPDATE
  `l_file` = VALUES(`l_file`),
  `m_file` = VALUES(`m_file`),
  `r_file` = VALUES(`r_file`),
  `l_transcription` = VALUES(`l_transcription`),
  `m_transcription` = VALUES(`m_transcription`),
  `r_transcription` = VALUES(`r_transcription`),
  `definitive_outcome` = VALUES(`definitive_outcome`),
  `added` = VALUES(`added`),
  `a_file` = VALUES(`a_file`),
  `b_file` = VALUES(`b_file`),
  `a_transcription` = VALUES(`a_transcription`),
  `b_transcription` = VALUES(`b_transcription`),
  `videoCategory` = VALUES(`videoCategory`),
  `videoLabel` = VALUES(`videoLabel`),
  `zOg` = VALUES(`zOg`),
  `videoTop` = VALUES(`videoTop`),
  `post_processed` = VALUES(`post_processed`),
  `signbank_upload` = VALUES(`signbank_upload`),
  `time` = VALUES(`time`),
  `date` = VALUES(`date`),
  `format` = VALUES(`format`),
  `tyd_converted` = VALUES(`tyd_converted`),
  `rendered` = VALUES(`rendered`),
  `converted` = VALUES(`converted`),
  `render_date` = VALUES(`render_date`),
  `convert_date` = VALUES(`convert_date`),
  `thumbnail` = VALUES(`thumbnail`),
  `thumbnail_date` = VALUES(`thumbnail_date`),
  `tyd_rendered` = VALUES(`tyd_rendered`),
  `tyd_thumbnail` = VALUES(`tyd_thumbnail`),
  `app_ready` = VALUES(`app_ready`),
  `has_mocap` = VALUES(`has_mocap`),
  `has_sam` = VALUES(`has_sam`);

-- The 20 recordings themselves.
INSERT INTO `CameraRecords`
  (`id`,`camera1`,`stateVideo`,`datetime_ms`,`glosId`,`videoTop`,`stopTime`,`startTime`,`camera2`,`camera3`,`camera4`,`camera5`,`glos`,`zOg`,`videoLabel`,`videoCategory`,`clips`, `user`)
VALUES
('21553','44','stopped','1741941117063','1711','0444642232de7ae6f709a12b20394d5ab676c32f5339b356bad65e05cbe827e8.webm','2025-03-14T08:31:56.997Z','2025-03-14T08:31:53.930Z','44','44','44','44','','Glos',NULL,NULL,NULL,@demo_user),
('21561','52','stopped','1741941247520','1721','06c7b1f5fa4075ec3f82ee44f7c031aae8bd503a32d7bf42dd9f6df574d3e413.webm','2025-03-14T08:34:07.400Z','2025-03-14T08:34:04.319Z','52','52','52','52','','Glos',NULL,NULL,NULL,@demo_user),
('21562','53','stopped','1741941265038','1722','84e93ab17b15d0da3075496ffbe608454bfa18d8540b4f685d7cb66c543680bb.webm','2025-03-14T08:34:24.958Z','2025-03-14T08:34:21.874Z','53','53','53','53','','Glos',NULL,NULL,NULL,@demo_user),
('21563','54','stopped','1741941280339','1725','7b9695e7e891e1845fed26c29987f5ccb0ed0d2f2f457f0c3bdc7cd6b974abc7.webm','2025-03-14T08:34:40.247Z','2025-03-14T08:34:37.177Z','54','54','54','54','','Glos',NULL,NULL,NULL,@demo_user),
('21566','57','stopped','1741941322414','87','44711fe0f3e23535b8c499e4887141c423a1e50558a1c0226973bbf20dbb8c60.webm','2025-03-14T08:35:22.343Z','2025-03-14T08:35:19.242Z','57','57','57','57','','Glos',NULL,NULL,NULL,@demo_user),
('21572','63','stopped','1741941480960','1602','7fd8ea93352fd2bf643dca8b2d7a2109e6039b0815dd27986040418aaea69aaf.webm','2025-03-14T08:38:00.883Z','2025-03-14T08:37:57.838Z','63','63','63','63','','Glos',NULL,NULL,NULL,@demo_user),
('21574','65','stopped','1741941519375','8580','5c883a93bf3814c8b8a15510bfc79e3010392acf000f24abfcc3c95c5a71dc58.webm','2025-03-14T08:38:39.295Z','2025-03-14T08:38:36.196Z','65','65','65','65','','Glos',NULL,NULL,NULL,@demo_user),
('21591','82','stopped','1741941923974','108','653dd396d28e2f130f55b036b540f583a324e9a4b8f41066cc6a14e1dcf78502.webm','2025-03-14T08:45:23.881Z','2025-03-14T08:45:20.797Z','82','82','82','82','','Glos',NULL,NULL,NULL,@demo_user),
('21605','96','stopped','1741942203325','1072','2af2ed790c2d3cd475dd4504b26a72ca4378a325de1422119debd5cb612defb6.webm','2025-03-14T08:50:03.237Z','2025-03-14T08:50:00.159Z','96','96','96','96','kabouter','Glos',NULL,NULL,NULL,@demo_user),
('21612','103','stopped','1741942316158','437','dd2a319b2106661f9b5f802405d77dc4ae193702916c591295076faf7614f52b.webm','2025-03-14T08:51:56.063Z','2025-03-14T08:51:52.962Z','103','103','103','103','','Glos',NULL,NULL,NULL,@demo_user),
('36885','95','stopped','1769422807795','4211','dbefaac630a4c5952817f5d612610a33c4dc07a74fb3357ee8ee89aceb67b120.webm','2026-01-26T10:20:07.753Z','2026-01-26T10:20:02.735Z','95','95','95','95','De pasta is warm.','Zin',NULL,NULL,NULL,@demo_user),
('36887','97','stopped','1769422841575','4212','729c1675b18d896309110dfe043b9b058fc7f6ce7d5891a46a2101f6a991d08d.webm','2026-01-26T10:20:41.515Z','2026-01-26T10:20:36.834Z','97','97','97','97','Heb je genoeg gegeten?','Zin',NULL,NULL,NULL,@demo_user),
('37354','104','stopped','1769508277635','4216','3fb48444485a0494a73e699c9af2554dd1a549fcaffaaae7de3ce43d65ca60ab.webm','2026-01-27T10:04:37.578Z','2026-01-27T10:04:33.875Z','104','104','104','104','Wat wil je bestellen?','Zin',NULL,NULL,NULL,@demo_user),
('37524','274','stopped','1769521499932','4217','a08b0e404a5907cf2782cb7ba4f9195c3e44c2300a0897629b5dd57bb0827caa.webm','2026-01-27T13:44:59.875Z','2026-01-27T13:44:54.840Z','274','274','274','274','we kunnen niet alles doorspoelen','Zin',NULL,NULL,NULL,@demo_user),
('40724','363','stopped','1771942824997','1','7267679e92728c88fd4fc859ce92d41cdc0272ad83e2a068a21fa8a3c2c612d6.webm','2026-02-24T14:20:24.933Z','2026-02-24T14:20:20.671Z','363','363','363','363','Doe je je jas aan?','Zin',NULL,NULL,NULL,@demo_user),
('40740','379','stopped','1771943560213','1926','43d1a21c967a4a3b890702cc41ff36cba712f2f49193bc483b473951eb61773f.webm','2026-02-24T14:32:40.106Z','2026-02-24T14:32:34.770Z','379','379','379','379','Zal ik kijken wat voor weer het wordt vandaag?','Zin',NULL,NULL,NULL,@demo_user),
('41248','365','stopped','1772199197440','2024','3a3d26f181545f9c4069741623397bc38533b4b5c266fb4dbd4b6f8e29e43366.webm','2026-02-27T13:33:17.252Z','2026-02-27T13:33:12.886Z','365','365','365','365','Je moet nog even je druppels nemen.','Zin',NULL,NULL,NULL,@demo_user),
('41253','370','stopped','1772199519113','846','84ebc0ab4aa44484d701d29fe89e9c7b7435a826b4dd4c5dad3b32744ac36715.webm','2026-02-27T13:38:39.092Z','2026-02-27T13:38:34.624Z','370','370','370','370','Heb je zin in je fles?','Zin',NULL,NULL,NULL,@demo_user),
('41279','396','stopped','1772201907108','960','7fd8e941f8a15beaac4fb8d5b3010d498bda115b48e3b926a86bcc218d3fd487.webm','2026-02-27T14:18:27.061Z','2026-02-27T14:18:22.158Z','396','396','396','396','je moest wel nodig plassen hè?','Zin',NULL,NULL,NULL,@demo_user),
('41296','413','stopped','1772202904819','870','25ef060ad4b6cb96d3383cc73f16a723c59f827de952e11246d619b9a58f1839.webm','2026-02-27T14:35:04.667Z','2026-02-27T14:34:59.637Z','413','413','413','413','De kapper kan wel goed knippen, hè?','Zin',NULL,NULL,NULL,@demo_user)

ON DUPLICATE KEY UPDATE
  `camera1` = VALUES(`camera1`),
  `stateVideo` = VALUES(`stateVideo`),
  `datetime_ms` = VALUES(`datetime_ms`),
  `glosId` = VALUES(`glosId`),
  `videoTop` = VALUES(`videoTop`),
  `stopTime` = VALUES(`stopTime`),
  `startTime` = VALUES(`startTime`),
  `camera2` = VALUES(`camera2`),
  `camera3` = VALUES(`camera3`),
  `camera4` = VALUES(`camera4`),
  `camera5` = VALUES(`camera5`),
  `glos` = VALUES(`glos`),
  `zOg` = VALUES(`zOg`),
  `videoLabel` = VALUES(`videoLabel`),
  `videoCategory` = VALUES(`videoCategory`),
  `clips` = VALUES(`clips`),
  `user` = VALUES(`user`);
