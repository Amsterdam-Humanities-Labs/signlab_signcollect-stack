-- MySQL dump 10.13  Distrib 8.0.46, for Linux (x86_64)
--
-- Host: localhost    Database: admin_gebarenoverleg
-- ------------------------------------------------------
-- Server version	8.0.46-0ubuntu0.24.04.4

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `CameraRecords`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `CameraRecords` (
  `id` int NOT NULL AUTO_INCREMENT,
  `camera1` varchar(255) DEFAULT NULL,
  `stateVideo` varchar(255) DEFAULT NULL,
  `datetime_ms` varchar(255) DEFAULT NULL,
  `glosId` varchar(255) DEFAULT NULL,
  `videoTop` varchar(255) DEFAULT NULL,
  `stopTime` varchar(255) DEFAULT NULL,
  `startTime` varchar(255) DEFAULT NULL,
  `camera2` int DEFAULT NULL,
  `camera3` int DEFAULT NULL,
  `camera4` int DEFAULT NULL,
  `camera5` int DEFAULT NULL,
  `glos` varchar(255) DEFAULT NULL,
  `zOg` varchar(255) DEFAULT NULL,
  `user` varchar(255) DEFAULT NULL,
  `videoLabel` varchar(255) DEFAULT NULL,
  `videoCategory` varchar(255) DEFAULT NULL,
  `clips` text,
  PRIMARY KEY (`id`),
  KEY `idx_glosId` (`glosId`),
  KEY `idx_zOg` (`zOg`)
) ENGINE=InnoDB AUTO_INCREMENT=50833 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `activity_log`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `activity_log` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `userId` int NOT NULL,
  `page` varchar(255) NOT NULL,
  `visited_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_visited_at` (`visited_at`),
  KEY `idx_user_visited` (`userId`,`visited_at`)
) ENGINE=InnoDB AUTO_INCREMENT=4894 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `capture_assignments`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `capture_assignments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(255) NOT NULL,
  `capture_date` date NOT NULL,
  `assigned_by` varchar(255) NOT NULL,
  `assigned_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_date` (`capture_date`)
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `captures`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `captures` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Name of the capture/animation',
  `theme` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Theme or category for grouping captures',
  `captured` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Whether the capture has been recorded (0=no, 1=yes)',
  `captured_time` timestamp NULL DEFAULT NULL COMMENT 'When the capture was completed',
  `has_fbx` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Whether FBX file is available (0=no, 1=yes)',
  `has_glb` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Whether GLB file is available (0=no, 1=yes)',
  `has_csv` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Whether CSV file is available (0=no, 1=yes)',
  `has_mp4` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Whether MP4 file is available (0=no, 1=yes)',
  `video_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT 'URL to the MP4 video file',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When the capture record was created',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'When the record was last updated',
  PRIMARY KEY (`id`),
  KEY `idx_theme` (`theme`),
  KEY `idx_captured` (`captured`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Motion capture management table';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `chat_history`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `chat_history` (
  `id` int NOT NULL AUTO_INCREMENT,
  `session_id` varchar(36) NOT NULL,
  `message_type` enum('user','assistant') NOT NULL,
  `message` text NOT NULL,
  `response_data` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_session_id` (`session_id`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=263 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `client_metrics`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `client_metrics` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `client_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `cpu_percent` decimal(5,2) NOT NULL COMMENT 'CPU usage percentage (0-100)',
  `cpu_wait_percent` decimal(5,2) DEFAULT NULL COMMENT 'I/O wait percentage (0-100)',
  `disk_usage_percent` decimal(5,2) NOT NULL COMMENT 'Disk usage percentage (0-100)',
  `disk_total_gb` decimal(10,2) DEFAULT NULL COMMENT 'Total disk size in GB',
  `disk_used_gb` decimal(10,2) DEFAULT NULL COMMENT 'Used disk space in GB',
  `disk_free_gb` decimal(10,2) DEFAULT NULL COMMENT 'Free disk space in GB',
  `memory_percent` decimal(5,2) DEFAULT NULL COMMENT 'Memory usage percentage (optional)',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_client_timestamp` (`client_id`,`timestamp` DESC),
  KEY `idx_timestamp` (`timestamp`),
  CONSTRAINT `fk_metrics_client` FOREIGN KEY (`client_id`) REFERENCES `client_monitors` (`client_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=6389 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Stores hourly system metrics for clients';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `client_monitors`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `client_monitors` (
  `id` int NOT NULL AUTO_INCREMENT,
  `client_id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `client_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `status` enum('online','offline','warning') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'offline',
  `last_seen` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `metadata` json DEFAULT NULL,
  `heartbeat_interval` int NOT NULL DEFAULT '3600' COMMENT 'Expected heartbeat interval in seconds',
  `warning_threshold` decimal(3,2) NOT NULL DEFAULT '1.50' COMMENT 'Multiplier for warning status',
  `offline_threshold` decimal(3,2) NOT NULL DEFAULT '2.00' COMMENT 'Multiplier for offline status',
  PRIMARY KEY (`id`),
  UNIQUE KEY `client_id` (`client_id`),
  KEY `idx_client_id` (`client_id`),
  KEY `idx_status` (`status`),
  KEY `idx_last_seen` (`last_seen`)
) ENGINE=InnoDB AUTO_INCREMENT=95 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `csl_glosses`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `csl_glosses` (
  `id` int NOT NULL AUTO_INCREMENT,
  `glos` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `glos_engels` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `senses` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `senses_engels` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gloss_id` int NOT NULL,
  `take` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `video` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `take_date` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `pineapple` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `take_file` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  UNIQUE KEY `id_2` (`id`),
  KEY `id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1770 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `deaftech_media`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `deaftech_media` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `filename` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `original_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `mime_type` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `file_size` int unsigned NOT NULL,
  `file_path` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `thumbnail_path` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `alt_text` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `caption` text COLLATE utf8mb4_unicode_ci,
  `uploaded_by` int unsigned DEFAULT NULL,
  `width` int unsigned DEFAULT NULL,
  `height` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mime_type` (`mime_type`),
  KEY `idx_uploaded_by` (`uploaded_by`),
  CONSTRAINT `deaftech_media_ibfk_1` FOREIGN KEY (`uploaded_by`) REFERENCES `deaftech_users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `deaftech_page_revisions`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `deaftech_page_revisions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `page_id` int unsigned NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `content` longtext COLLATE utf8mb4_unicode_ci,
  `meta_description` text COLLATE utf8mb4_unicode_ci,
  `revision_author` int unsigned DEFAULT NULL,
  `revision_message` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_page_id` (`page_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `revision_author` (`revision_author`),
  CONSTRAINT `deaftech_page_revisions_ibfk_1` FOREIGN KEY (`page_id`) REFERENCES `deaftech_pages` (`id`) ON DELETE CASCADE,
  CONSTRAINT `deaftech_page_revisions_ibfk_2` FOREIGN KEY (`revision_author`) REFERENCES `deaftech_users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `deaftech_pages`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `deaftech_pages` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `slug` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `meta_description` text COLLATE utf8mb4_unicode_ci,
  `content` longtext COLLATE utf8mb4_unicode_ci,
  `template` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'default',
  `status` enum('published','draft','archived') COLLATE utf8mb4_unicode_ci DEFAULT 'draft',
  `author_id` int unsigned DEFAULT NULL,
  `featured_image` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `menu_order` int DEFAULT '0',
  `show_in_menu` tinyint(1) DEFAULT '1',
  `custom_css` text COLLATE utf8mb4_unicode_ci,
  `custom_js` text COLLATE utf8mb4_unicode_ci,
  `published_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `slug` (`slug`),
  KEY `idx_slug` (`slug`),
  KEY `idx_status` (`status`),
  KEY `idx_menu_order` (`menu_order`),
  KEY `author_id` (`author_id`),
  CONSTRAINT `deaftech_pages_ibfk_1` FOREIGN KEY (`author_id`) REFERENCES `deaftech_users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `deaftech_sessions`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `deaftech_sessions` (
  `id` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` int unsigned DEFAULT NULL,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `payload` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_activity` int NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_last_activity` (`last_activity`),
  CONSTRAINT `deaftech_sessions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `deaftech_users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `deaftech_settings`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `deaftech_settings` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `setting_key` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `setting_value` text COLLATE utf8mb4_unicode_ci,
  `setting_type` enum('text','number','boolean','json','html') COLLATE utf8mb4_unicode_ci DEFAULT 'text',
  `description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `setting_key` (`setting_key`),
  KEY `idx_setting_key` (`setting_key`)
) ENGINE=InnoDB AUTO_INCREMENT=60 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `deaftech_users`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `deaftech_users` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `full_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` enum('admin','editor','viewer') COLLATE utf8mb4_unicode_ci DEFAULT 'editor',
  `is_active` tinyint(1) DEFAULT '1',
  `last_login` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`),
  KEY `idx_username` (`username`),
  KEY `idx_email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `download_logs`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `download_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(255) NOT NULL,
  `file_id` bigint NOT NULL,
  `filename` varchar(512) NOT NULL,
  `download_type` enum('original','processed','bulk','upload','mark_processed','mark_unprocessed','eaf') NOT NULL DEFAULT 'original',
  `downloaded_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_username` (`username`),
  KEY `idx_downloaded_at` (`downloaded_at`)
) ENGINE=InnoDB AUTO_INCREMENT=2899 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `form_data`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `form_data` (
  `id` int NOT NULL AUTO_INCREMENT,
  `signbank` varchar(255) DEFAULT NULL,
  `wie` varchar(255) DEFAULT NULL,
  `actie` text,
  `entry` varchar(255) DEFAULT NULL,
  `gbc` varchar(255) DEFAULT NULL,
  `glos` varchar(255) DEFAULT NULL,
  `wanneer` varchar(255) DEFAULT NULL,
  `wie_snel_opname` varchar(255) DEFAULT NULL,
  `control_nodig` varchar(255) DEFAULT NULL,
  `fonologie_fase1` varchar(255) DEFAULT NULL,
  `fonologie_fase2` varchar(255) DEFAULT NULL,
  `senses` text,
  `linkSignbank` varchar(255) DEFAULT NULL,
  `logboek` longtext,
  `woord` varchar(255) DEFAULT NULL,
  `videoLeft` text,
  `videoCenter` text,
  `videoRight` text,
  `studioOpnameStatus` varchar(255) DEFAULT NULL,
  `studioOpnameWie` varchar(255) DEFAULT NULL,
  `signbank_status` varchar(255) DEFAULT NULL,
  `glosZichtbaar` varchar(255) NOT NULL DEFAULT '0',
  `zelfopname` text,
  `thema` varchar(255) CHARACTER SET latin1 COLLATE latin1_swedish_ci DEFAULT NULL,
  `signbank_opname` varchar(255) DEFAULT NULL,
  `glos_engels` varchar(255) DEFAULT NULL,
  `glosVeranderen` varchar(255) DEFAULT NULL,
  `OpnameThreeD` varchar(255) DEFAULT NULL,
  `unreal_take` text,
  `glosStatus` text,
  `handvorm` text,
  `Handeness` varchar(255) DEFAULT NULL,
  `strongHand` varchar(255) DEFAULT NULL,
  `weakHand` varchar(255) DEFAULT NULL,
  `handLocation` varchar(255) DEFAULT NULL,
  `captureStartTime` text,
  `videoTop` text,
  `synced` varchar(255) DEFAULT NULL,
  `HandshapeChange` varchar(255) DEFAULT NULL,
  `RelationArticulators` varchar(255) DEFAULT NULL,
  `relOrientationMove` varchar(255) DEFAULT NULL,
  `relOrientationLoc` varchar(255) DEFAULT NULL,
  `orientationChange` varchar(255) DEFAULT NULL,
  `ContactType` varchar(255) DEFAULT NULL,
  `MovementShape` varchar(255) DEFAULT NULL,
  `MovementDirection` varchar(255) DEFAULT NULL,
  `RepeatedMovement` varchar(255) DEFAULT NULL,
  `AlternatingMovement` varchar(255) DEFAULT NULL,
  `madeByWie` varchar(255) DEFAULT NULL,
  `relativeOrienationMovement` varchar(255) DEFAULT NULL,
  `relativeOrienationLocation` varchar(255) DEFAULT NULL,
  `virtualObjectt` varchar(255) DEFAULT NULL,
  `phonologyOther` varchar(255) DEFAULT NULL,
  `mouthGesture` varchar(255) DEFAULT NULL,
  `mouthing` varchar(255) DEFAULT NULL,
  `phoneticVariation` varchar(255) DEFAULT NULL,
  `processed` varchar(255) DEFAULT NULL,
  `sensesEngels` text,
  `process_zelfopname` varchar(255) DEFAULT NULL,
  `morfologie` varchar(255) DEFAULT NULL,
  `videoA` varchar(255) DEFAULT NULL,
  `videoB` varchar(255) DEFAULT NULL,
  `origin` varchar(255) DEFAULT NULL,
  `extern` varchar(255) DEFAULT NULL,
  `labels` varchar(255) DEFAULT NULL,
  `werkwoord` varchar(255) DEFAULT NULL,
  `tyd_app_ready` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_id` (`id`),
  KEY `ix_form_data_search` (`id`,`signbank`,`glos`),
  KEY `idx_form_data_glosZichtbaar` (`glosZichtbaar`)
) ENGINE=InnoDB AUTO_INCREMENT=67887 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `form_submissions`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `form_submissions` (
  `id` int NOT NULL AUTO_INCREMENT,
  `query` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `timestamp` datetime NOT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text,
  `status` enum('pending','processed','rejected') DEFAULT 'pending',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `processed_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `freemocap_data`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `freemocap_data` (
  `id` int NOT NULL AUTO_INCREMENT,
  `date` varchar(255) DEFAULT NULL,
  `calibrated` varchar(255) DEFAULT NULL,
  `m_file` varchar(255) DEFAULT NULL,
  `r_file` varchar(255) DEFAULT NULL,
  `l_file` varchar(255) DEFAULT NULL,
  `a_file` varchar(255) DEFAULT NULL,
  `b_file` varchar(255) DEFAULT NULL,
  `role` varchar(255) DEFAULT NULL,
  `synced` varchar(255) DEFAULT NULL,
  `glosId` varchar(255) DEFAULT NULL,
  `animation` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1845 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `gloss_notes`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `gloss_notes` (
  `id` int NOT NULL AUTO_INCREMENT,
  `dataset` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL,
  `gloss_id` int NOT NULL,
  `user_id` int NOT NULL,
  `note_text` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dataset_gloss` (`dataset`,`gloss_id`,`created_at`),
  KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hand_pose_files`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hand_pose_files` (
  `file_id` bigint NOT NULL AUTO_INCREMENT,
  `filename` varchar(255) NOT NULL,
  `file_path` varchar(500) NOT NULL,
  `file_size` bigint DEFAULT NULL,
  `total_frames` int DEFAULT NULL,
  `r_hand_frames` int DEFAULT '0',
  `l_hand_frames` int DEFAULT '0',
  `processed_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `session_date` varchar(20) DEFAULT NULL,
  `processing_status` varchar(20) DEFAULT 'pending',
  `error_message` text,
  PRIMARY KEY (`file_id`),
  UNIQUE KEY `filename` (`filename`),
  KEY `idx_filename` (`filename`),
  KEY `idx_processing_status` (`processing_status`),
  KEY `idx_processed_date` (`processed_date`)
) ENGINE=InnoDB AUTO_INCREMENT=3735 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hand_pose_finger_distances`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hand_pose_finger_distances` (
  `distance_id` bigint NOT NULL AUTO_INCREMENT,
  `file_id` bigint NOT NULL,
  `frame_number` int NOT NULL,
  `hand_type` enum('l_hand','r_hand') NOT NULL,
  `thumb_total_distance` double DEFAULT NULL,
  `index_total_distance` double DEFAULT NULL,
  `middle_total_distance` double DEFAULT NULL,
  `ring_total_distance` double DEFAULT NULL,
  `pinky_total_distance` double DEFAULT NULL,
  PRIMARY KEY (`distance_id`),
  UNIQUE KEY `unique_frame_distance` (`file_id`,`frame_number`,`hand_type`),
  KEY `idx_file_id` (`file_id`),
  KEY `idx_frame_number` (`frame_number`),
  KEY `idx_hand_type` (`hand_type`),
  KEY `idx_thumb_distance` (`thumb_total_distance`),
  KEY `idx_index_distance` (`index_total_distance`),
  KEY `idx_middle_distance` (`middle_total_distance`),
  KEY `idx_ring_distance` (`ring_total_distance`),
  KEY `idx_pinky_distance` (`pinky_total_distance`),
  CONSTRAINT `hand_pose_finger_distances_ibfk_1` FOREIGN KEY (`file_id`) REFERENCES `hand_pose_files` (`file_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1320490 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hand_pose_finger_spreads`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hand_pose_finger_spreads` (
  `spread_id` bigint NOT NULL AUTO_INCREMENT,
  `file_id` bigint NOT NULL,
  `frame_number` int NOT NULL,
  `hand_type` enum('l_hand','r_hand') NOT NULL,
  `thumb_index_spread` double DEFAULT NULL,
  `index_middle_spread` double DEFAULT NULL,
  `middle_ring_spread` double DEFAULT NULL,
  `ring_pinky_spread` double DEFAULT NULL,
  PRIMARY KEY (`spread_id`),
  UNIQUE KEY `unique_frame_spread` (`file_id`,`frame_number`,`hand_type`),
  KEY `idx_file_id` (`file_id`),
  KEY `idx_frame_number` (`frame_number`),
  KEY `idx_hand_type` (`hand_type`),
  CONSTRAINT `hand_pose_finger_spreads_ibfk_1` FOREIGN KEY (`file_id`) REFERENCES `hand_pose_files` (`file_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1320490 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hand_pose_fingertip_distances`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hand_pose_fingertip_distances` (
  `fingertip_id` bigint NOT NULL AUTO_INCREMENT,
  `file_id` bigint NOT NULL,
  `frame_number` int NOT NULL,
  `hand_type` enum('l_hand','r_hand') NOT NULL,
  `thumb_index_distance` double DEFAULT NULL,
  `thumb_middle_distance` double DEFAULT NULL,
  `thumb_ring_distance` double DEFAULT NULL,
  `thumb_pinky_distance` double DEFAULT NULL,
  `index_middle_distance` double DEFAULT NULL,
  `index_ring_distance` double DEFAULT NULL,
  `index_pinky_distance` double DEFAULT NULL,
  `middle_ring_distance` double DEFAULT NULL,
  `middle_pinky_distance` double DEFAULT NULL,
  `ring_pinky_distance` double DEFAULT NULL,
  PRIMARY KEY (`fingertip_id`),
  UNIQUE KEY `unique_frame_fingertip` (`file_id`,`frame_number`,`hand_type`),
  KEY `idx_file_id` (`file_id`),
  KEY `idx_frame_number` (`frame_number`),
  KEY `idx_hand_type` (`hand_type`),
  CONSTRAINT `hand_pose_fingertip_distances_ibfk_1` FOREIGN KEY (`file_id`) REFERENCES `hand_pose_files` (`file_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1320490 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary view structure for view `hand_pose_similarity_search`
--

SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `hand_pose_similarity_search` AS SELECT 
 1 AS `file_id`,
 1 AS `filename`,
 1 AS `distance_id`,
 1 AS `frame_number`,
 1 AS `hand_type`,
 1 AS `thumb_total_distance`,
 1 AS `index_total_distance`,
 1 AS `middle_total_distance`,
 1 AS `ring_total_distance`,
 1 AS `pinky_total_distance`,
 1 AS `thumb_index_spread`,
 1 AS `index_middle_spread`,
 1 AS `middle_ring_spread`,
 1 AS `ring_pinky_spread`*/;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `handshapes`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `handshapes` (
  `id` int NOT NULL AUTO_INCREMENT,
  `handshape_pool_name` varchar(255) DEFAULT NULL,
  `handshape_pool_id` int DEFAULT NULL,
  `handshape_photo` longblob,
  `video_name` varchar(255) DEFAULT NULL,
  `video_time` float DEFAULT NULL,
  `hand` varchar(10) DEFAULT NULL,
  `median_landmarks` json DEFAULT NULL,
  `date_added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1374 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hh_index`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hh_index` (
  `id` int NOT NULL AUTO_INCREMENT,
  `url` varchar(255) DEFAULT NULL,
  `plain_text` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `keywords` varchar(255) DEFAULT NULL,
  `ngt_text` text,
  `zelfopname` varchar(255) DEFAULT NULL,
  `labels` varchar(255) DEFAULT NULL,
  `priority` int DEFAULT NULL,
  `status` varchar(255) DEFAULT NULL,
  `ngt_text2` text,
  `ngt_text3` text,
  `ngt_text4` text,
  `naam` varchar(255) DEFAULT NULL,
  `status_video` varchar(50) DEFAULT '',
  `status_glos` varchar(50) DEFAULT '',
  `status_nederlands` varchar(50) DEFAULT '',
  `status_gvg` varchar(50) DEFAULT '',
  `comments` text,
  `video_count` int DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `url` (`url`)
) ENGINE=InnoDB AUTO_INCREMENT=9184 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hh_index_glos`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hh_index_glos` (
  `id` int NOT NULL AUTO_INCREMENT,
  `hh_index_id` varchar(255) NOT NULL,
  `glos` varchar(255) NOT NULL,
  `text` text NOT NULL,
  KEY `id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1273 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hh_lemma`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hh_lemma` (
  `id` int NOT NULL AUTO_INCREMENT,
  `lemma` varchar(255) DEFAULT NULL,
  `video` varchar(255) DEFAULT NULL,
  `origin` varchar(255) DEFAULT NULL,
  `video_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=58270 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hh_logs`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hh_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `action` varchar(255) NOT NULL,
  `parameters` text,
  `ip_address` varchar(45) NOT NULL,
  `username` varchar(100) DEFAULT NULL,
  `datetime` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=253 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hh_segments`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hh_segments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `base_filename` varchar(255) NOT NULL COMMENT 'e.g. M20250610_9217',
  `segment_number` int NOT NULL,
  `filename` varchar(255) NOT NULL COMMENT 'e.g. M20250610_9217_3.mp4',
  `location` enum('raw','post','both') NOT NULL DEFAULT 'raw',
  `file_size_raw` bigint DEFAULT NULL,
  `file_size_post` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_base_segment` (`base_filename`,`segment_number`),
  KEY `idx_base_filename` (`base_filename`)
) ENGINE=InnoDB AUTO_INCREMENT=399624 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hh_sentences`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hh_sentences` (
  `sentence` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `sentence_id` int DEFAULT NULL,
  `id` int NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`),
  KEY `sentence_id` (`sentence_id`),
  KEY `id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=256018 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hh_synonyms`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hh_synonyms` (
  `id` int NOT NULL AUTO_INCREMENT,
  `lemma` varchar(255) NOT NULL,
  `synonym` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_lemma` (`lemma`),
  KEY `idx_synonym` (`synonym`)
) ENGINE=InnoDB AUTO_INCREMENT=19573 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hh_words`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hh_words` (
  `word` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `word_id` int DEFAULT NULL,
  `id` int NOT NULL AUTO_INCREMENT,
  `lemma` varchar(255) DEFAULT NULL,
  `origin` varchar(255) DEFAULT NULL,
  `video_id` varchar(255) DEFAULT NULL,
  `video` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `word_id` (`word_id`),
  KEY `ix_hh_words_search` (`id`,`word`,`lemma`)
) ENGINE=InnoDB AUTO_INCREMENT=4754 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hh_words_old`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hh_words_old` (
  `word` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `word_id` int DEFAULT NULL,
  `id` int NOT NULL AUTO_INCREMENT,
  `lemma` varchar(255) DEFAULT NULL,
  `origin` varchar(255) DEFAULT NULL,
  `video_id` varchar(255) DEFAULT NULL,
  `video` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `word_id` (`word_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `jb_woorden`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `jb_woorden` (
  `id` int NOT NULL AUTO_INCREMENT,
  `woord` varchar(255) DEFAULT NULL,
  `lemma` varchar(255) DEFAULT NULL,
  `fd_id` int DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  UNIQUE KEY `id_2` (`id`),
  KEY `id` (`id`),
  KEY `id_3` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2745 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `labels`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `labels` (
  `id` int NOT NULL AUTO_INCREMENT,
  `label` varchar(255) DEFAULT NULL,
  `color` varchar(255) DEFAULT NULL,
  `dataset` varchar(16) NOT NULL DEFAULT 'ngt',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=202 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lemmaTable`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lemmaTable` (
  `id` int NOT NULL AUTO_INCREMENT,
  `lemma` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `lemma` (`lemma`),
  KEY `idx_lemma` (`lemma`)
) ENGINE=InnoDB AUTO_INCREMENT=2476 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lsm_data`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lsm_data` (
  `id` int NOT NULL AUTO_INCREMENT,
  `signbank` varchar(255) DEFAULT NULL,
  `wie` varchar(255) DEFAULT NULL,
  `actie` text,
  `entry` varchar(255) DEFAULT NULL,
  `gbc` varchar(255) DEFAULT NULL,
  `glos` varchar(255) DEFAULT NULL,
  `wanneer` varchar(255) DEFAULT NULL,
  `wie_snel_opname` varchar(255) DEFAULT NULL,
  `control_nodig` varchar(255) DEFAULT NULL,
  `fonologie_fase1` varchar(255) DEFAULT NULL,
  `fonologie_fase2` varchar(255) DEFAULT NULL,
  `senses` text,
  `linkSignbank` varchar(255) DEFAULT NULL,
  `logboek` longtext,
  `woord` varchar(255) DEFAULT NULL,
  `videoLeft` text,
  `videoCenter` text,
  `videoRight` text,
  `studioOpnameStatus` varchar(255) DEFAULT NULL,
  `studioOpnameWie` varchar(255) DEFAULT NULL,
  `signbank_status` varchar(255) DEFAULT NULL,
  `glosZichtbaar` varchar(255) NOT NULL DEFAULT '0',
  `zelfopname` text,
  `thema` varchar(255) CHARACTER SET latin1 COLLATE latin1_swedish_ci DEFAULT NULL,
  `signbank_opname` varchar(255) DEFAULT NULL,
  `glos_engels` varchar(255) DEFAULT NULL,
  `glosVeranderen` varchar(255) DEFAULT NULL,
  `OpnameThreeD` varchar(255) DEFAULT NULL,
  `unreal_take` text,
  `glosStatus` text,
  `handvorm` text,
  `Handeness` varchar(255) DEFAULT NULL,
  `strongHand` varchar(255) DEFAULT NULL,
  `weakHand` varchar(255) DEFAULT NULL,
  `handLocation` varchar(255) DEFAULT NULL,
  `captureStartTime` text,
  `videoTop` text,
  `synced` varchar(255) DEFAULT NULL,
  `HandshapeChange` varchar(255) DEFAULT NULL,
  `RelationArticulators` varchar(255) DEFAULT NULL,
  `relOrientationMove` varchar(255) DEFAULT NULL,
  `relOrientationLoc` varchar(255) DEFAULT NULL,
  `orientationChange` varchar(255) DEFAULT NULL,
  `ContactType` varchar(255) DEFAULT NULL,
  `MovementShape` varchar(255) DEFAULT NULL,
  `MovementDirection` varchar(255) DEFAULT NULL,
  `RepeatedMovement` varchar(255) DEFAULT NULL,
  `AlternatingMovement` varchar(255) DEFAULT NULL,
  `madeByWie` varchar(255) DEFAULT NULL,
  `relativeOrienationMovement` varchar(255) DEFAULT NULL,
  `relativeOrienationLocation` varchar(255) DEFAULT NULL,
  `virtualObjectt` varchar(255) DEFAULT NULL,
  `phonologyOther` varchar(255) DEFAULT NULL,
  `mouthGesture` varchar(255) DEFAULT NULL,
  `mouthing` varchar(255) DEFAULT NULL,
  `phoneticVariation` varchar(255) DEFAULT NULL,
  `processed` varchar(255) DEFAULT NULL,
  `sensesEngels` text,
  `process_zelfopname` varchar(255) DEFAULT NULL,
  `morfologie` varchar(255) DEFAULT NULL,
  `videoA` varchar(255) DEFAULT NULL,
  `videoB` varchar(255) DEFAULT NULL,
  `origin` varchar(255) DEFAULT NULL,
  `extern` varchar(255) DEFAULT NULL,
  `labels` varchar(255) DEFAULT NULL,
  `werkwoord` varchar(255) DEFAULT NULL,
  `tyd_app_ready` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_id` (`id`),
  KEY `ix_form_data_search` (`id`,`signbank`,`glos`),
  KEY `idx_form_data_glosZichtbaar` (`glosZichtbaar`)
) ENGINE=InnoDB AUTO_INCREMENT=172 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `matched_transcriptions`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `matched_transcriptions` (
  `id` int NOT NULL AUTO_INCREMENT,
  `l_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `m_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `r_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `l_transcription` text CHARACTER SET latin1,
  `m_transcription` text CHARACTER SET latin1,
  `r_transcription` text CHARACTER SET latin1,
  `definitive_outcome` text CHARACTER SET latin1,
  `added` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoCategory` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoLabel` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zOg` varchar(255) CHARACTER SET latin1 NOT NULL,
  `videoTop` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `post_processed` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `signbank_upload` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `time` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `format` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_converted` int DEFAULT NULL,
  `rendered` int DEFAULT NULL,
  `converted` int DEFAULT NULL,
  `render_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `convert_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `thumbnail` int DEFAULT NULL,
  `thumbnail_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_rendered` int DEFAULT NULL,
  `tyd_thumbnail` int DEFAULT NULL,
  `app_ready` int DEFAULT '0',
  `has_mocap` int DEFAULT NULL,
  `has_sam` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_m_file` (`m_file`),
  KEY `idx_mocap_filter` (`zOg`,`added`,`has_mocap`,`m_transcription`(20)),
  KEY `idx_m_file_zog` (`m_file`,`zOg`),
  KEY `idx_mt_transcription` (`m_transcription`(13),`zOg`,`added`)
) ENGINE=InnoDB AUTO_INCREMENT=67034 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `matched_transcriptions_backup_20251222`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `matched_transcriptions_backup_20251222` (
  `id` int NOT NULL DEFAULT '0',
  `l_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `m_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `r_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `l_transcription` text CHARACTER SET latin1,
  `m_transcription` text CHARACTER SET latin1,
  `r_transcription` text CHARACTER SET latin1,
  `definitive_outcome` text CHARACTER SET latin1,
  `added` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoCategory` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoLabel` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zOg` varchar(255) CHARACTER SET latin1 NOT NULL,
  `videoTop` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `post_processed` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `signbank_upload` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `time` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `format` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_converted` int DEFAULT NULL,
  `rendered` int DEFAULT NULL,
  `converted` int DEFAULT NULL,
  `render_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `convert_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `thumbnail` int DEFAULT NULL,
  `thumbnail_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_rendered` int DEFAULT NULL,
  `tyd_thumbnail` int DEFAULT NULL,
  `app_ready` int DEFAULT '0',
  `has_mocap` int DEFAULT NULL,
  `has_sam` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `matched_transcriptions_backup_20260106_111021`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `matched_transcriptions_backup_20260106_111021` (
  `id` int NOT NULL DEFAULT '0',
  `l_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `m_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `r_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `l_transcription` text CHARACTER SET latin1,
  `m_transcription` text CHARACTER SET latin1,
  `r_transcription` text CHARACTER SET latin1,
  `definitive_outcome` text CHARACTER SET latin1,
  `added` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoCategory` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoLabel` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zOg` varchar(255) CHARACTER SET latin1 NOT NULL,
  `videoTop` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `post_processed` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `signbank_upload` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `time` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `format` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_converted` int DEFAULT NULL,
  `rendered` int DEFAULT NULL,
  `converted` int DEFAULT NULL,
  `render_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `convert_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `thumbnail` int DEFAULT NULL,
  `thumbnail_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_rendered` int DEFAULT NULL,
  `tyd_thumbnail` int DEFAULT NULL,
  `app_ready` int DEFAULT '0',
  `has_mocap` int DEFAULT NULL,
  `has_sam` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `matched_transcriptions_backup_20260106_111110`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `matched_transcriptions_backup_20260106_111110` (
  `id` int NOT NULL DEFAULT '0',
  `l_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `m_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `r_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `l_transcription` text CHARACTER SET latin1,
  `m_transcription` text CHARACTER SET latin1,
  `r_transcription` text CHARACTER SET latin1,
  `definitive_outcome` text CHARACTER SET latin1,
  `added` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoCategory` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoLabel` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zOg` varchar(255) CHARACTER SET latin1 NOT NULL,
  `videoTop` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `post_processed` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `signbank_upload` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `time` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `format` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_converted` int DEFAULT NULL,
  `rendered` int DEFAULT NULL,
  `converted` int DEFAULT NULL,
  `render_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `convert_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `thumbnail` int DEFAULT NULL,
  `thumbnail_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_rendered` int DEFAULT NULL,
  `tyd_thumbnail` int DEFAULT NULL,
  `app_ready` int DEFAULT '0',
  `has_mocap` int DEFAULT NULL,
  `has_sam` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `matched_transcriptions_backup_20260106_111149`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `matched_transcriptions_backup_20260106_111149` (
  `id` int NOT NULL DEFAULT '0',
  `l_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `m_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `r_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `l_transcription` text CHARACTER SET latin1,
  `m_transcription` text CHARACTER SET latin1,
  `r_transcription` text CHARACTER SET latin1,
  `definitive_outcome` text CHARACTER SET latin1,
  `added` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoCategory` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoLabel` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zOg` varchar(255) CHARACTER SET latin1 NOT NULL,
  `videoTop` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `post_processed` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `signbank_upload` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `time` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `format` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_converted` int DEFAULT NULL,
  `rendered` int DEFAULT NULL,
  `converted` int DEFAULT NULL,
  `render_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `convert_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `thumbnail` int DEFAULT NULL,
  `thumbnail_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_rendered` int DEFAULT NULL,
  `tyd_thumbnail` int DEFAULT NULL,
  `app_ready` int DEFAULT '0',
  `has_mocap` int DEFAULT NULL,
  `has_sam` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `matched_transcriptions_backup_20260106_112758`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `matched_transcriptions_backup_20260106_112758` (
  `id` int NOT NULL DEFAULT '0',
  `l_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `m_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `r_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `l_transcription` text CHARACTER SET latin1,
  `m_transcription` text CHARACTER SET latin1,
  `r_transcription` text CHARACTER SET latin1,
  `definitive_outcome` text CHARACTER SET latin1,
  `added` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoCategory` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoLabel` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zOg` varchar(255) CHARACTER SET latin1 NOT NULL,
  `videoTop` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `post_processed` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `signbank_upload` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `time` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `format` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_converted` int DEFAULT NULL,
  `rendered` int DEFAULT NULL,
  `converted` int DEFAULT NULL,
  `render_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `convert_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `thumbnail` int DEFAULT NULL,
  `thumbnail_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_rendered` int DEFAULT NULL,
  `tyd_thumbnail` int DEFAULT NULL,
  `app_ready` int DEFAULT '0',
  `has_mocap` int DEFAULT NULL,
  `has_sam` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `matched_transcriptions_backup_20260106_113646`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `matched_transcriptions_backup_20260106_113646` (
  `id` int NOT NULL DEFAULT '0',
  `l_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `m_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `r_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `l_transcription` text CHARACTER SET latin1,
  `m_transcription` text CHARACTER SET latin1,
  `r_transcription` text CHARACTER SET latin1,
  `definitive_outcome` text CHARACTER SET latin1,
  `added` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoCategory` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoLabel` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zOg` varchar(255) CHARACTER SET latin1 NOT NULL,
  `videoTop` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `post_processed` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `signbank_upload` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `time` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `format` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_converted` int DEFAULT NULL,
  `rendered` int DEFAULT NULL,
  `converted` int DEFAULT NULL,
  `render_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `convert_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `thumbnail` int DEFAULT NULL,
  `thumbnail_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_rendered` int DEFAULT NULL,
  `tyd_thumbnail` int DEFAULT NULL,
  `app_ready` int DEFAULT '0',
  `has_mocap` int DEFAULT NULL,
  `has_sam` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `matched_transcriptions_backup_20260106_114200`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `matched_transcriptions_backup_20260106_114200` (
  `id` int NOT NULL DEFAULT '0',
  `l_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `m_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `r_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `l_transcription` text CHARACTER SET latin1,
  `m_transcription` text CHARACTER SET latin1,
  `r_transcription` text CHARACTER SET latin1,
  `definitive_outcome` text CHARACTER SET latin1,
  `added` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoCategory` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoLabel` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zOg` varchar(255) CHARACTER SET latin1 NOT NULL,
  `videoTop` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `post_processed` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `signbank_upload` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `time` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `format` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_converted` int DEFAULT NULL,
  `rendered` int DEFAULT NULL,
  `converted` int DEFAULT NULL,
  `render_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `convert_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `thumbnail` int DEFAULT NULL,
  `thumbnail_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_rendered` int DEFAULT NULL,
  `tyd_thumbnail` int DEFAULT NULL,
  `app_ready` int DEFAULT '0',
  `has_mocap` int DEFAULT NULL,
  `has_sam` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `matched_transcriptions_backup_20260106_144142`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `matched_transcriptions_backup_20260106_144142` (
  `id` int NOT NULL DEFAULT '0',
  `l_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `m_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `r_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `l_transcription` text CHARACTER SET latin1,
  `m_transcription` text CHARACTER SET latin1,
  `r_transcription` text CHARACTER SET latin1,
  `definitive_outcome` text CHARACTER SET latin1,
  `added` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoCategory` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoLabel` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zOg` varchar(255) CHARACTER SET latin1 NOT NULL,
  `videoTop` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `post_processed` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `signbank_upload` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `time` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `format` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_converted` int DEFAULT NULL,
  `rendered` int DEFAULT NULL,
  `converted` int DEFAULT NULL,
  `render_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `convert_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `thumbnail` int DEFAULT NULL,
  `thumbnail_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_rendered` int DEFAULT NULL,
  `tyd_thumbnail` int DEFAULT NULL,
  `app_ready` int DEFAULT '0',
  `has_mocap` int DEFAULT NULL,
  `has_sam` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `matched_transcriptions_backup_20260112_095913`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `matched_transcriptions_backup_20260112_095913` (
  `id` int NOT NULL DEFAULT '0',
  `l_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `m_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `r_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `l_transcription` text CHARACTER SET latin1,
  `m_transcription` text CHARACTER SET latin1,
  `r_transcription` text CHARACTER SET latin1,
  `definitive_outcome` text CHARACTER SET latin1,
  `added` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoCategory` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoLabel` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zOg` varchar(255) CHARACTER SET latin1 NOT NULL,
  `videoTop` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `post_processed` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `signbank_upload` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `time` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `format` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_converted` int DEFAULT NULL,
  `rendered` int DEFAULT NULL,
  `converted` int DEFAULT NULL,
  `render_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `convert_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `thumbnail` int DEFAULT NULL,
  `thumbnail_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_rendered` int DEFAULT NULL,
  `tyd_thumbnail` int DEFAULT NULL,
  `app_ready` int DEFAULT '0',
  `has_mocap` int DEFAULT NULL,
  `has_sam` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `matched_transcriptions_backup_20260112_095938`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `matched_transcriptions_backup_20260112_095938` (
  `id` int NOT NULL DEFAULT '0',
  `l_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `m_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `r_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `l_transcription` text CHARACTER SET latin1,
  `m_transcription` text CHARACTER SET latin1,
  `r_transcription` text CHARACTER SET latin1,
  `definitive_outcome` text CHARACTER SET latin1,
  `added` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_file` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `a_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `b_transcription` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoCategory` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `videoLabel` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zOg` varchar(255) CHARACTER SET latin1 NOT NULL,
  `videoTop` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `post_processed` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `signbank_upload` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `time` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `format` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_converted` int DEFAULT NULL,
  `rendered` int DEFAULT NULL,
  `converted` int DEFAULT NULL,
  `render_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `convert_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `thumbnail` int DEFAULT NULL,
  `thumbnail_date` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `tyd_rendered` int DEFAULT NULL,
  `tyd_thumbnail` int DEFAULT NULL,
  `app_ready` int DEFAULT '0',
  `has_mocap` int DEFAULT NULL,
  `has_sam` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `matched_transcriptions_test`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `matched_transcriptions_test` (
  `id` int NOT NULL AUTO_INCREMENT,
  `l_file` varchar(255) DEFAULT NULL,
  `m_file` varchar(255) DEFAULT NULL,
  `r_file` varchar(255) DEFAULT NULL,
  `l_transcription` text,
  `m_transcription` text,
  `r_transcription` text,
  `definitive_outcome` text,
  `added` varchar(255) DEFAULT NULL,
  `a_file` varchar(255) DEFAULT NULL,
  `b_file` varchar(255) DEFAULT NULL,
  `a_transcription` varchar(255) DEFAULT NULL,
  `b_transcription` varchar(255) DEFAULT NULL,
  `videoCategory` varchar(255) DEFAULT NULL,
  `videoLabel` varchar(255) DEFAULT NULL,
  `zOg` varchar(255) NOT NULL,
  `videoTop` varchar(255) DEFAULT NULL,
  `post_processed` varchar(255) DEFAULT NULL,
  `signbank_upload` varchar(255) DEFAULT NULL,
  `time` varchar(255) DEFAULT NULL,
  `date` varchar(255) DEFAULT NULL,
  `format` varchar(255) DEFAULT NULL,
  `tyd_converted` int DEFAULT NULL,
  `rendered` int DEFAULT NULL,
  `converted` int DEFAULT NULL,
  `render_date` varchar(255) DEFAULT NULL,
  `convert_date` varchar(255) DEFAULT NULL,
  `thumbnail` int DEFAULT NULL,
  `thumbnail_date` varchar(255) DEFAULT NULL,
  `tyd_rendered` int DEFAULT NULL,
  `tyd_thumbnail` int DEFAULT NULL,
  `app_ready` int DEFAULT '0',
  `has_mocap` int DEFAULT NULL,
  `has_sam` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_matched_transcriptions_search` (`id`,`m_file`,`m_transcription`(255),`definitive_outcome`(255),`zOg`),
  KEY `idx_mt_zOg_added` (`zOg`,`added`)
) ENGINE=InnoDB AUTO_INCREMENT=159 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `mocap_data`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `mocap_data` (
  `id` int NOT NULL AUTO_INCREMENT,
  `glos` varchar(255) DEFAULT NULL,
  `glos_engels` varchar(255) DEFAULT NULL,
  `senses` varchar(255) DEFAULT NULL,
  `senses_engels` varchar(255) DEFAULT NULL,
  `gloss_id` int NOT NULL,
  `take` varchar(255) DEFAULT NULL,
  `video` varchar(255) DEFAULT NULL,
  `take_date` varchar(255) DEFAULT NULL,
  `pineapple` varchar(255) DEFAULT NULL,
  UNIQUE KEY `id_2` (`id`),
  KEY `id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7341 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `mocap_files`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `mocap_files` (
  `id` int NOT NULL AUTO_INCREMENT,
  `glos` varchar(255) NOT NULL,
  `take` varchar(255) NOT NULL,
  `datetime` varchar(255) NOT NULL,
  `avatarName` varchar(255) NOT NULL,
  `filename` varchar(255) NOT NULL,
  `ll_metadata` varchar(255) DEFAULT NULL,
  `vicon_fbx` varchar(255) DEFAULT NULL,
  `vicon_csv` varchar(255) DEFAULT NULL,
  `has_fbx` int DEFAULT NULL,
  `video_filename` varchar(255) NOT NULL,
  `has_video` int DEFAULT NULL,
  `startTime` varchar(255) DEFAULT NULL,
  `endTime` varchar(255) DEFAULT NULL,
  `is_pp` tinyint(1) DEFAULT '0' COMMENT 'Post-processing status: 0 = not processed, 1 = processed',
  `filename_pp` varchar(255) DEFAULT NULL COMMENT 'Filename of the post-processed file',
  `datetime_pp` datetime DEFAULT NULL,
  `review_status` enum('pending','approved','rejected','needs_review') DEFAULT 'pending',
  UNIQUE KEY `id_2` (`id`),
  KEY `id` (`id`),
  KEY `idx_is_pp` (`is_pp`),
  KEY `idx_datetime` (`datetime`)
) ENGINE=InnoDB AUTO_INCREMENT=11268 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `mocap_recording_logs`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `mocap_recording_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `recording_mode` enum('regular','theme','zinnen') NOT NULL,
  `sentence_id` int DEFAULT NULL,
  `broadcast_name` varchar(50) DEFAULT NULL,
  `capture_id` int DEFAULT NULL,
  `glos_name` varchar(255) DEFAULT NULL,
  `theme` varchar(255) DEFAULT NULL,
  `user_id` varchar(255) DEFAULT NULL,
  `take_number` int DEFAULT '0',
  `recorded_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_recorded_at` (`recorded_at`),
  KEY `idx_sentence` (`sentence_id`),
  KEY `idx_user` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2556 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ngt_data`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ngt_data` (
  `id` int NOT NULL AUTO_INCREMENT,
  `glos` varchar(255) DEFAULT NULL,
  `glos_engels` varchar(255) DEFAULT NULL,
  `senses` varchar(255) DEFAULT NULL,
  `senses_engels` varchar(255) DEFAULT NULL,
  `gloss_id` int NOT NULL,
  `take` varchar(255) DEFAULT NULL,
  `video` varchar(255) DEFAULT NULL,
  `take_date` varchar(255) DEFAULT NULL,
  `pineapple` varchar(255) DEFAULT NULL,
  UNIQUE KEY `id_2` (`id`),
  KEY `id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7341 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `nmm_data`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nmm_data` (
  `id` int NOT NULL AUTO_INCREMENT,
  `signbank_id` varchar(255) DEFAULT NULL,
  `glos` varchar(255) DEFAULT NULL,
  `zelfopname` varchar(255) DEFAULT NULL,
  `type` varchar(255) DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  UNIQUE KEY `id_2` (`id`),
  KEY `id` (`id`),
  KEY `ix_nmm_data_search` (`id`,`glos`,`type`)
) ENGINE=InnoDB AUTO_INCREMENT=4492 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `nmm_data_backup`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nmm_data_backup` (
  `id` int NOT NULL AUTO_INCREMENT,
  `signbank_id` varchar(255) DEFAULT NULL,
  `glos` varchar(255) DEFAULT NULL,
  `zelfopname` varchar(255) DEFAULT NULL,
  `type` varchar(255) DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  UNIQUE KEY `id_2` (`id`),
  KEY `id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4483 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `reference_handshapes`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reference_handshapes` (
  `reference_id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `description` text,
  `category` varchar(50) DEFAULT 'general',
  `file_id` bigint NOT NULL,
  `frame_number` int NOT NULL,
  `hand_type` enum('l_hand','r_hand') NOT NULL,
  `thumb_total_distance` double DEFAULT NULL,
  `index_total_distance` double DEFAULT NULL,
  `middle_total_distance` double DEFAULT NULL,
  `ring_total_distance` double DEFAULT NULL,
  `pinky_total_distance` double DEFAULT NULL,
  `thumb_index_spread` double DEFAULT NULL,
  `index_middle_spread` double DEFAULT NULL,
  `middle_ring_spread` double DEFAULT NULL,
  `ring_pinky_spread` double DEFAULT NULL,
  `thumb_index_distance` double DEFAULT NULL,
  `thumb_middle_distance` double DEFAULT NULL,
  `thumb_ring_distance` double DEFAULT NULL,
  `thumb_pinky_distance` double DEFAULT NULL,
  `index_middle_distance` double DEFAULT NULL,
  `index_ring_distance` double DEFAULT NULL,
  `index_pinky_distance` double DEFAULT NULL,
  `middle_ring_distance` double DEFAULT NULL,
  `middle_pinky_distance` double DEFAULT NULL,
  `ring_pinky_distance` double DEFAULT NULL,
  `created_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(100) DEFAULT 'system',
  `thumbnail_path` varchar(500) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`reference_id`),
  UNIQUE KEY `unique_reference` (`file_id`,`frame_number`,`hand_type`,`name`),
  KEY `idx_name` (`name`),
  KEY `idx_category` (`category`),
  KEY `idx_active` (`is_active`),
  KEY `idx_created_date` (`created_date`),
  KEY `idx_source` (`file_id`,`frame_number`,`hand_type`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sb_records`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sb_records` (
  `id` int NOT NULL,
  `lemma_id_gloss_dutch` varchar(255) DEFAULT NULL,
  `lemma_id_gloss_english` varchar(255) DEFAULT NULL,
  `annotation_id_gloss_dutch` varchar(255) DEFAULT NULL,
  `annotation_id_gloss_english` varchar(255) DEFAULT NULL,
  `senses_dutch` json DEFAULT NULL,
  `senses_english` json DEFAULT NULL,
  `handedness` varchar(50) DEFAULT NULL,
  `strong_hand` varchar(50) DEFAULT NULL,
  `location` varchar(255) DEFAULT NULL,
  `in_web_dictionary` tinyint(1) DEFAULT NULL,
  `is_proposed_new_sign` tinyint(1) DEFAULT NULL,
  `exclude_from_ecv` tinyint(1) DEFAULT NULL,
  `relative_orientation_movement` varchar(255) DEFAULT NULL,
  `relative_orientation_location` varchar(255) DEFAULT NULL,
  `repeated_movement` tinyint(1) DEFAULT NULL,
  `alternating_movement` tinyint(1) DEFAULT NULL,
  `movement_direction` varchar(255) DEFAULT NULL,
  `link` varchar(512) DEFAULT NULL,
  `video` varchar(512) DEFAULT NULL,
  `affiliation` json DEFAULT NULL,
  `perspective_videos` json DEFAULT NULL,
  `nme_videos` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_lemma_dutch` (`lemma_id_gloss_dutch`),
  KEY `idx_lemma_english` (`lemma_id_gloss_english`),
  KEY `idx_annotation_dutch` (`annotation_id_gloss_dutch`),
  KEY `idx_annotation_english` (`annotation_id_gloss_english`),
  KEY `idx_location` (`location`),
  KEY `idx_strong_hand` (`strong_hand`),
  FULLTEXT KEY `idx_fulltext` (`lemma_id_gloss_dutch`,`lemma_id_gloss_english`,`annotation_id_gloss_dutch`,`annotation_id_gloss_english`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `search_cache`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `search_cache` (
  `cache_id` bigint NOT NULL AUTO_INCREMENT,
  `query_hash` varchar(64) NOT NULL,
  `search_metrics` json NOT NULL,
  `cache_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `last_file_id` bigint DEFAULT NULL,
  `last_updated` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `hit_count` int DEFAULT '1',
  `total_results` int DEFAULT '0',
  PRIMARY KEY (`cache_id`),
  UNIQUE KEY `query_hash` (`query_hash`),
  KEY `idx_query_hash` (`query_hash`),
  KEY `idx_last_file_id` (`last_file_id`),
  KEY `idx_hit_count` (`hit_count`),
  KEY `idx_cache_date` (`cache_date`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `search_cache_results`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `search_cache_results` (
  `result_id` bigint NOT NULL AUTO_INCREMENT,
  `cache_id` bigint NOT NULL,
  `frame_id` bigint NOT NULL,
  `file_id` bigint NOT NULL,
  `filename` varchar(255) DEFAULT NULL,
  `frame_number` int DEFAULT NULL,
  `hand_type` varchar(10) DEFAULT NULL,
  `similarity_score` double DEFAULT NULL,
  `thumb_total_distance` double DEFAULT NULL,
  `index_total_distance` double DEFAULT NULL,
  `middle_total_distance` double DEFAULT NULL,
  `ring_total_distance` double DEFAULT NULL,
  `pinky_total_distance` double DEFAULT NULL,
  `thumb_index_spread` double DEFAULT NULL,
  `index_middle_spread` double DEFAULT NULL,
  `middle_ring_spread` double DEFAULT NULL,
  `ring_pinky_spread` double DEFAULT NULL,
  `thumb_index_distance` double DEFAULT NULL,
  `thumb_middle_distance` double DEFAULT NULL,
  `thumb_ring_distance` double DEFAULT NULL,
  `thumb_pinky_distance` double DEFAULT NULL,
  `index_middle_distance` double DEFAULT NULL,
  `index_ring_distance` double DEFAULT NULL,
  `index_pinky_distance` double DEFAULT NULL,
  `middle_ring_distance` double DEFAULT NULL,
  `middle_pinky_distance` double DEFAULT NULL,
  `ring_pinky_distance` double DEFAULT NULL,
  PRIMARY KEY (`result_id`),
  UNIQUE KEY `unique_cache_frame` (`cache_id`,`frame_id`),
  KEY `idx_cache_id` (`cache_id`),
  KEY `idx_frame_id` (`frame_id`),
  KEY `idx_file_id` (`file_id`),
  KEY `idx_similarity_score` (`cache_id`,`similarity_score`),
  KEY `idx_cache_frame` (`cache_id`,`frame_id`),
  CONSTRAINT `search_cache_results_ibfk_1` FOREIGN KEY (`cache_id`) REFERENCES `search_cache` (`cache_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=267415 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `search_history`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `search_history` (
  `search_id` bigint NOT NULL AUTO_INCREMENT,
  `upload_id` bigint DEFAULT NULL,
  `source_filename` varchar(255) DEFAULT NULL,
  `frame_number` int DEFAULT NULL,
  `hand_type` varchar(10) DEFAULT NULL,
  `search_metrics` json DEFAULT NULL,
  `similarity_weights` json DEFAULT NULL,
  `hand_type_filter` varchar(10) DEFAULT NULL,
  `result_limit` int DEFAULT NULL,
  `results_count` int DEFAULT NULL,
  `top_similarity_score` double DEFAULT NULL,
  `search_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `label` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`search_id`),
  KEY `idx_search_date` (`search_date`),
  KEY `idx_upload_id` (`upload_id`),
  KEY `idx_source_filename` (`source_filename`),
  CONSTRAINT `search_history_ibfk_1` FOREIGN KEY (`upload_id`) REFERENCES `upload_history` (`upload_id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `search_tasks`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `search_tasks` (
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `query_hash` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `search_params` json NOT NULL,
  `status` enum('pending','processing','completed','failed','cancelled','timeout') COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `progress` int DEFAULT '0',
  `total_results` int DEFAULT '0',
  `message` text COLLATE utf8mb4_unicode_ci,
  `result_cache_id` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `started_at` timestamp NULL DEFAULT NULL,
  `completed_at` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` text COLLATE utf8mb4_unicode_ci,
  `custom_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'User-defined name to identify the handshape search',
  PRIMARY KEY (`task_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_expires_at` (`expires_at`),
  KEY `idx_query_hash` (`query_hash`),
  KEY `idx_custom_name` (`custom_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences` (
  `ID` int NOT NULL AUTO_INCREMENT,
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `comments` text,
  `status_annotatie` varchar(255) DEFAULT 'Niet Klaar',
  `status_glos` varchar(255) DEFAULT 'Niet Klaar',
  `status_video` varchar(255) DEFAULT 'Niet Klaar',
  `mcp_status_postprocessing` varchar(255) DEFAULT NULL,
  `mcp_status_tijd_annotatie` varchar(255) DEFAULT NULL,
  `mcp_status_tijd_annotatie_gvg` varchar(255) DEFAULT NULL,
  `zinString` text,
  `zinStringEAF` text,
  `glosses` text,
  `lemmaList` text,
  `search_lemma` varchar(255) DEFAULT NULL,
  `gvg` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `ai_Occurences` text,
  `lemma_processed` tinyint(1) DEFAULT '0',
  `lemma_processed_at` timestamp NULL DEFAULT NULL,
  `lemma_error` text,
  `eaf_synced_at` timestamp NULL DEFAULT NULL,
  `eaf_sync_status` enum('pending','synced','error','no_eaf') DEFAULT 'pending',
  `eaf_sync_error` text,
  `status_gvg` varchar(255) DEFAULT NULL,
  `video_count` int NOT NULL DEFAULT '0',
  `videoTop` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `idx_zinStringEAF` (`zinStringEAF`(100)),
  KEY `idx_eaf_sync_status` (`eaf_sync_status`),
  KEY `idx_sentences_status_video` (`status_video`),
  KEY `idx_sentences_status_glos` (`status_glos`),
  KEY `idx_sentences_status_gvg` (`status_gvg`),
  KEY `idx_sentences_status_annotatie` (`status_annotatie`),
  KEY `idx_sentences_thema` (`thema`(50))
) ENGINE=InnoDB AUTO_INCREMENT=6462 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_20250728_113520`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_20250728_113520` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) CHARACTER SET latin1 COLLATE latin1_swedish_ci DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `comments` text CHARACTER SET latin1,
  `status` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_annotatie` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_glos` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_video` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zinString` text CHARACTER SET latin1,
  `glosses` text CHARACTER SET latin1,
  `lemmaList` text CHARACTER SET latin1,
  `search_lemma` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `gvg` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `label` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `ai_Occurences` text CHARACTER SET latin1,
  `lemma_processed` tinyint(1) DEFAULT '0' COMMENT 'Whether AI lemma processing has been completed',
  `lemma_processed_at` timestamp NULL DEFAULT NULL COMMENT 'When the lemma was last processed',
  `lemma_error` text CHARACTER SET latin1 COMMENT 'Any error message from lemma processing'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_20250728_113601`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_20250728_113601` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) CHARACTER SET latin1 COLLATE latin1_swedish_ci DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `comments` text CHARACTER SET latin1,
  `status` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_annotatie` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_glos` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_video` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zinString` text CHARACTER SET latin1,
  `glosses` text CHARACTER SET latin1,
  `lemmaList` text CHARACTER SET latin1,
  `search_lemma` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `gvg` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `label` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `ai_Occurences` text CHARACTER SET latin1,
  `lemma_processed` tinyint(1) DEFAULT '0' COMMENT 'Whether AI lemma processing has been completed',
  `lemma_processed_at` timestamp NULL DEFAULT NULL COMMENT 'When the lemma was last processed',
  `lemma_error` text CHARACTER SET latin1 COMMENT 'Any error message from lemma processing'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_20250729_081049`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_20250729_081049` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `comments` text,
  `status` varchar(255) DEFAULT 'Niet Klaar',
  `status_annotatie` varchar(255) DEFAULT 'Niet Klaar',
  `status_glos` varchar(255) DEFAULT 'Niet Klaar',
  `status_video` varchar(255) DEFAULT 'Niet Klaar',
  `zinString` text,
  `glosses` text,
  `lemmaList` text,
  `search_lemma` varchar(255) DEFAULT NULL,
  `gvg` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `ai_Occurences` text,
  `lemma_processed` tinyint(1) DEFAULT '0',
  `lemma_processed_at` timestamp NULL DEFAULT NULL,
  `lemma_error` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_20250729_081103`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_20250729_081103` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `comments` text,
  `status` varchar(255) DEFAULT 'Niet Klaar',
  `status_annotatie` varchar(255) DEFAULT 'Niet Klaar',
  `status_glos` varchar(255) DEFAULT 'Niet Klaar',
  `status_video` varchar(255) DEFAULT 'Niet Klaar',
  `zinString` text,
  `glosses` text,
  `lemmaList` text,
  `search_lemma` varchar(255) DEFAULT NULL,
  `gvg` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `ai_Occurences` text,
  `lemma_processed` tinyint(1) DEFAULT '0',
  `lemma_processed_at` timestamp NULL DEFAULT NULL,
  `lemma_error` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_before_csv_import_20250728_114654`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_before_csv_import_20250728_114654` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) CHARACTER SET latin1 COLLATE latin1_swedish_ci DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `comments` text CHARACTER SET latin1,
  `status` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_annotatie` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_glos` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_video` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zinString` text CHARACTER SET latin1,
  `glosses` text CHARACTER SET latin1,
  `lemmaList` text CHARACTER SET latin1,
  `search_lemma` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `gvg` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `label` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `ai_Occurences` text CHARACTER SET latin1,
  `lemma_processed` tinyint(1) DEFAULT '0' COMMENT 'Whether AI lemma processing has been completed',
  `lemma_processed_at` timestamp NULL DEFAULT NULL COMMENT 'When the lemma was last processed',
  `lemma_error` text CHARACTER SET latin1 COMMENT 'Any error message from lemma processing'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_before_deletion_20250728_114236`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_before_deletion_20250728_114236` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) CHARACTER SET latin1 COLLATE latin1_swedish_ci DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `comments` text CHARACTER SET latin1,
  `status` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_annotatie` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_glos` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_video` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zinString` text CHARACTER SET latin1,
  `glosses` text CHARACTER SET latin1,
  `lemmaList` text CHARACTER SET latin1,
  `search_lemma` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `gvg` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `label` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `ai_Occurences` text CHARACTER SET latin1,
  `lemma_processed` tinyint(1) DEFAULT '0' COMMENT 'Whether AI lemma processing has been completed',
  `lemma_processed_at` timestamp NULL DEFAULT NULL COMMENT 'When the lemma was last processed',
  `lemma_error` text CHARACTER SET latin1 COMMENT 'Any error message from lemma processing'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_before_duplicate_fix_20250728_115714`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_before_duplicate_fix_20250728_115714` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) CHARACTER SET latin1 COLLATE latin1_swedish_ci DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `comments` text CHARACTER SET latin1,
  `status` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_annotatie` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_glos` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_video` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zinString` text CHARACTER SET latin1,
  `glosses` text CHARACTER SET latin1,
  `lemmaList` text CHARACTER SET latin1,
  `search_lemma` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `gvg` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `label` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `ai_Occurences` text CHARACTER SET latin1,
  `lemma_processed` tinyint(1) DEFAULT '0' COMMENT 'Whether AI lemma processing has been completed',
  `lemma_processed_at` timestamp NULL DEFAULT NULL COMMENT 'When the lemma was last processed',
  `lemma_error` text CHARACTER SET latin1 COMMENT 'Any error message from lemma processing'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_before_proper_id_fix_20250728_115616`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_before_proper_id_fix_20250728_115616` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) CHARACTER SET latin1 COLLATE latin1_swedish_ci DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `comments` text CHARACTER SET latin1,
  `status` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_annotatie` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_glos` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `status_video` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `zinString` text CHARACTER SET latin1,
  `glosses` text CHARACTER SET latin1,
  `lemmaList` text CHARACTER SET latin1,
  `search_lemma` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `gvg` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `label` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `ai_Occurences` text CHARACTER SET latin1,
  `lemma_processed` tinyint(1) DEFAULT '0' COMMENT 'Whether AI lemma processing has been completed',
  `lemma_processed_at` timestamp NULL DEFAULT NULL COMMENT 'When the lemma was last processed',
  `lemma_error` text CHARACTER SET latin1 COMMENT 'Any error message from lemma processing'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_before_status_update_20250728_120107`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_before_status_update_20250728_120107` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `comments` text,
  `status` varchar(255) DEFAULT NULL,
  `status_annotatie` varchar(255) DEFAULT NULL,
  `status_glos` varchar(255) DEFAULT NULL,
  `status_video` varchar(255) DEFAULT NULL,
  `zinString` text,
  `glosses` text,
  `lemmaList` text,
  `search_lemma` varchar(255) DEFAULT NULL,
  `gvg` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `ai_Occurences` text,
  `lemma_processed` tinyint(1) DEFAULT '0',
  `lemma_processed_at` timestamp NULL DEFAULT NULL,
  `lemma_error` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_pre_id_restore_20260106_111021`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_pre_id_restore_20260106_111021` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `comments` text,
  `status` varchar(255) DEFAULT 'Niet Klaar',
  `status_annotatie` varchar(255) DEFAULT 'Niet Klaar',
  `status_glos` varchar(255) DEFAULT 'Niet Klaar',
  `status_video` varchar(255) DEFAULT 'Niet Klaar',
  `zinString` text,
  `glosses` text,
  `lemmaList` text,
  `search_lemma` varchar(255) DEFAULT NULL,
  `gvg` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `ai_Occurences` text,
  `lemma_processed` tinyint(1) DEFAULT '0',
  `lemma_processed_at` timestamp NULL DEFAULT NULL,
  `lemma_error` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_pre_id_restore_20260106_111110`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_pre_id_restore_20260106_111110` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `comments` text,
  `status` varchar(255) DEFAULT 'Niet Klaar',
  `status_annotatie` varchar(255) DEFAULT 'Niet Klaar',
  `status_glos` varchar(255) DEFAULT 'Niet Klaar',
  `status_video` varchar(255) DEFAULT 'Niet Klaar',
  `zinString` text,
  `glosses` text,
  `lemmaList` text,
  `search_lemma` varchar(255) DEFAULT NULL,
  `gvg` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `ai_Occurences` text,
  `lemma_processed` tinyint(1) DEFAULT '0',
  `lemma_processed_at` timestamp NULL DEFAULT NULL,
  `lemma_error` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_pre_id_restore_20260106_111149`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_pre_id_restore_20260106_111149` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `comments` text,
  `status` varchar(255) DEFAULT 'Niet Klaar',
  `status_annotatie` varchar(255) DEFAULT 'Niet Klaar',
  `status_glos` varchar(255) DEFAULT 'Niet Klaar',
  `status_video` varchar(255) DEFAULT 'Niet Klaar',
  `zinString` text,
  `glosses` text,
  `lemmaList` text,
  `search_lemma` varchar(255) DEFAULT NULL,
  `gvg` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `ai_Occurences` text,
  `lemma_processed` tinyint(1) DEFAULT '0',
  `lemma_processed_at` timestamp NULL DEFAULT NULL,
  `lemma_error` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_pre_id_restore_20260106_112758`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_pre_id_restore_20260106_112758` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `comments` text,
  `status` varchar(255) DEFAULT 'Niet Klaar',
  `status_annotatie` varchar(255) DEFAULT 'Niet Klaar',
  `status_glos` varchar(255) DEFAULT 'Niet Klaar',
  `status_video` varchar(255) DEFAULT 'Niet Klaar',
  `zinString` text,
  `glosses` text,
  `lemmaList` text,
  `search_lemma` varchar(255) DEFAULT NULL,
  `gvg` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `ai_Occurences` text,
  `lemma_processed` tinyint(1) DEFAULT '0',
  `lemma_processed_at` timestamp NULL DEFAULT NULL,
  `lemma_error` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_pre_id_restore_20260106_113646`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_pre_id_restore_20260106_113646` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `comments` text,
  `status` varchar(255) DEFAULT 'Niet Klaar',
  `status_annotatie` varchar(255) DEFAULT 'Niet Klaar',
  `status_glos` varchar(255) DEFAULT 'Niet Klaar',
  `status_video` varchar(255) DEFAULT 'Niet Klaar',
  `zinString` text,
  `glosses` text,
  `lemmaList` text,
  `search_lemma` varchar(255) DEFAULT NULL,
  `gvg` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `ai_Occurences` text,
  `lemma_processed` tinyint(1) DEFAULT '0',
  `lemma_processed_at` timestamp NULL DEFAULT NULL,
  `lemma_error` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_pre_id_restore_20260106_114200`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_pre_id_restore_20260106_114200` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `comments` text,
  `status` varchar(255) DEFAULT 'Niet Klaar',
  `status_annotatie` varchar(255) DEFAULT 'Niet Klaar',
  `status_glos` varchar(255) DEFAULT 'Niet Klaar',
  `status_video` varchar(255) DEFAULT 'Niet Klaar',
  `zinString` text,
  `glosses` text,
  `lemmaList` text,
  `search_lemma` varchar(255) DEFAULT NULL,
  `gvg` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `ai_Occurences` text,
  `lemma_processed` tinyint(1) DEFAULT '0',
  `lemma_processed_at` timestamp NULL DEFAULT NULL,
  `lemma_error` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_pre_id_restore_20260106_144142`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_pre_id_restore_20260106_144142` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `comments` text,
  `status` varchar(255) DEFAULT 'Niet Klaar',
  `status_annotatie` varchar(255) DEFAULT 'Niet Klaar',
  `status_glos` varchar(255) DEFAULT 'Niet Klaar',
  `status_video` varchar(255) DEFAULT 'Niet Klaar',
  `zinString` text,
  `glosses` text,
  `lemmaList` text,
  `search_lemma` varchar(255) DEFAULT NULL,
  `gvg` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `ai_Occurences` text,
  `lemma_processed` tinyint(1) DEFAULT '0',
  `lemma_processed_at` timestamp NULL DEFAULT NULL,
  `lemma_error` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_pre_id_restore_20260112_095913`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_pre_id_restore_20260112_095913` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `comments` text,
  `status` varchar(255) DEFAULT 'Niet Klaar',
  `status_annotatie` varchar(255) DEFAULT 'Niet Klaar',
  `status_glos` varchar(255) DEFAULT 'Niet Klaar',
  `status_video` varchar(255) DEFAULT 'Niet Klaar',
  `zinString` text,
  `glosses` text,
  `lemmaList` text,
  `search_lemma` varchar(255) DEFAULT NULL,
  `gvg` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `ai_Occurences` text,
  `lemma_processed` tinyint(1) DEFAULT '0',
  `lemma_processed_at` timestamp NULL DEFAULT NULL,
  `lemma_error` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_backup_pre_id_restore_20260112_095938`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_backup_pre_id_restore_20260112_095938` (
  `ID` int NOT NULL DEFAULT '0',
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `comments` text,
  `status` varchar(255) DEFAULT 'Niet Klaar',
  `status_annotatie` varchar(255) DEFAULT 'Niet Klaar',
  `status_glos` varchar(255) DEFAULT 'Niet Klaar',
  `status_video` varchar(255) DEFAULT 'Niet Klaar',
  `zinString` text,
  `glosses` text,
  `lemmaList` text,
  `search_lemma` varchar(255) DEFAULT NULL,
  `gvg` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `ai_Occurences` text,
  `lemma_processed` tinyint(1) DEFAULT '0',
  `lemma_processed_at` timestamp NULL DEFAULT NULL,
  `lemma_error` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_logs`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `action` varchar(255) NOT NULL,
  `parameters` text,
  `ip_address` varchar(45) NOT NULL,
  `user` varchar(255) DEFAULT NULL,
  `datetime` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=50756 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sentences_temp_proper_fix`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sentences_temp_proper_fix` (
  `ID` int NOT NULL AUTO_INCREMENT,
  `zinID` int DEFAULT NULL,
  `glosArray` json DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `zinArray` json DEFAULT NULL,
  `thema` varchar(255) DEFAULT NULL,
  `sortArray` json DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `comments` text,
  `status` varchar(255) DEFAULT NULL,
  `status_annotatie` varchar(255) DEFAULT NULL,
  `status_glos` varchar(255) DEFAULT NULL,
  `status_video` varchar(255) DEFAULT NULL,
  `zinString` text,
  `glosses` text,
  `lemmaList` text,
  `search_lemma` varchar(255) DEFAULT NULL,
  `gvg` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `ai_Occurences` text,
  `lemma_processed` tinyint(1) DEFAULT '0',
  `lemma_processed_at` timestamp NULL DEFAULT NULL,
  `lemma_error` text,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB AUTO_INCREMENT=3884 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sequence_items`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sequence_items` (
  `id` int NOT NULL AUTO_INCREMENT,
  `sequence_id` int NOT NULL,
  `position` int NOT NULL,
  `sign_name` varchar(255) NOT NULL,
  `frame_start` int NOT NULL,
  `frame_end` int NOT NULL,
  `take_number` int NOT NULL,
  `item_data` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `sequence_id` (`sequence_id`),
  CONSTRAINT `sequence_items_ibfk_1` FOREIGN KEY (`sequence_id`) REFERENCES `sequences` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1801 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sequences`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sequences` (
  `id` int NOT NULL AUTO_INCREMENT,
  `sequence_name` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `user_id` varchar(255) DEFAULT NULL,
  `metadata` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=445 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `studio_data`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `studio_data` (
  `id` int NOT NULL AUTO_INCREMENT,
  `date` date DEFAULT NULL,
  `lastVideoNumber` varchar(255) NOT NULL DEFAULT '0',
  `processed` varchar(255) DEFAULT NULL,
  `camera1` int DEFAULT '0',
  `camera2` int DEFAULT '0',
  `camera3` int DEFAULT '0',
  `camera4` int DEFAULT '0',
  `camera5` int DEFAULT '0',
  `ready` varchar(255) NOT NULL DEFAULT '',
  `issues` text,
  `datetime_ms` varchar(255) DEFAULT NULL,
  `count_files` varchar(255) DEFAULT NULL,
  `l_count` int DEFAULT NULL,
  `r_count` int DEFAULT NULL,
  `m_count` int DEFAULT NULL,
  `a_count` int DEFAULT NULL,
  `b_count` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=321 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subtitles`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subtitles` (
  `id` int NOT NULL AUTO_INCREMENT,
  `content_id` int NOT NULL,
  `line_text` text NOT NULL,
  `start_time` double NOT NULL,
  `end_time` double NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `mode` varchar(10) DEFAULT 'toggle',
  `take` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=540 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `threeGlosses`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `threeGlosses` (
  `id` int NOT NULL AUTO_INCREMENT,
  `glos` varchar(255) DEFAULT NULL,
  `glos_engels` varchar(255) DEFAULT NULL,
  `senses` varchar(255) DEFAULT NULL,
  `senses_engels` varchar(255) DEFAULT NULL,
  `gloss_id` int NOT NULL,
  `take` varchar(255) DEFAULT NULL,
  `video` varchar(255) DEFAULT NULL,
  `take_date` varchar(255) DEFAULT NULL,
  `pineapple` varchar(255) DEFAULT NULL,
  `threeID` int NOT NULL,
  UNIQUE KEY `id_2` (`id`),
  KEY `id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7341 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `transcriptions`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `transcriptions` (
  `id` int NOT NULL AUTO_INCREMENT,
  `file_name` varchar(255) NOT NULL,
  `transcription` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6238 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `upload_history`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `upload_history` (
  `upload_id` bigint NOT NULL AUTO_INCREMENT,
  `original_filename` varchar(255) NOT NULL,
  `temp_filename` varchar(255) NOT NULL,
  `file_path` text,
  `file_size` bigint DEFAULT NULL,
  `total_frames` int DEFAULT NULL,
  `r_hand_frames` int DEFAULT '0',
  `l_hand_frames` int DEFAULT '0',
  `processing_status` varchar(20) DEFAULT 'completed',
  `upload_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`upload_id`),
  KEY `idx_upload_date` (`upload_date`),
  KEY `idx_original_filename` (`original_filename`),
  KEY `idx_temp_filename` (`temp_filename`)
) ENGINE=InnoDB AUTO_INCREMENT=108 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `userId` int NOT NULL AUTO_INCREMENT,
  `user` varchar(255) NOT NULL,
  `pass` varchar(255) NOT NULL,
  `logboek` text NOT NULL,
  `tableCheck` text NOT NULL,
  `lang` varchar(255) NOT NULL,
  `last_login` datetime DEFAULT NULL,
  `last_activity` datetime DEFAULT NULL,
  `last_page` varchar(255) DEFAULT NULL,
  `blocked` tinyint(1) NOT NULL DEFAULT '0',
  `role` varchar(20) NOT NULL DEFAULT 'user',
  `default_context` varchar(20) NOT NULL DEFAULT 'signio',
  `default_dataset` varchar(16) NOT NULL DEFAULT 'ngt',
  `allowed_datasets` json DEFAULT NULL,
  PRIMARY KEY (`userId`)
) ENGINE=InnoDB AUTO_INCREMENT=38 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `vicon_captures`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vicon_captures` (
  `id` int NOT NULL AUTO_INCREMENT,
  `capture_id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'e.g., 2026-01-21/M20260115_0568_260121_1',
  `date_dir` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'e.g., 2026-01-21',
  `recording_dir` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'e.g., M20260115_0568_260121_1',
  `first_seen` datetime NOT NULL,
  `last_modified` datetime NOT NULL,
  `file_count` int DEFAULT '0',
  `total_size_bytes` bigint DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `capture_id` (`capture_id`),
  KEY `idx_date_dir` (`date_dir`),
  KEY `idx_recording_dir` (`recording_dir`),
  KEY `idx_last_modified` (`last_modified`)
) ENGINE=InnoDB AUTO_INCREMENT=223065181 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `vicon_files`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vicon_files` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `capture_id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Foreign key to vicon_captures.capture_id',
  `file_path` varchar(1024) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Full Windows path',
  `filename` varchar(512) COLLATE utf8mb4_unicode_ci NOT NULL,
  `glb_path` varchar(1024) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Path to corresponding GLB file in /web/gebarenoverleg_media/fbx',
  `subdirectory` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'unreal, obs, shogun_live, shogun_post, root, etc.',
  `size_bytes` bigint NOT NULL,
  `status` enum('growing','complete') COLLATE utf8mb4_unicode_ci DEFAULT 'complete',
  `first_seen` datetime NOT NULL,
  `last_modified` datetime NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `is_pp` tinyint(1) NOT NULL DEFAULT '0',
  `filename_pp` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `datetime_pp` datetime DEFAULT NULL,
  `review_status` enum('pending','approved','rejected','needs_review') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `comment` text COLLATE utf8mb4_unicode_ci,
  `comment_by` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_file_path` (`file_path`(255)),
  KEY `idx_capture_id` (`capture_id`),
  KEY `idx_subdirectory` (`subdirectory`),
  KEY `idx_filename` (`filename`(191)),
  KEY `idx_status` (`status`),
  KEY `idx_last_modified` (`last_modified`),
  KEY `idx_glb_path` (`glb_path`(255)),
  CONSTRAINT `vicon_files_ibfk_1` FOREIGN KEY (`capture_id`) REFERENCES `vicon_captures` (`capture_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2032269104 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `vicon_monitor_metadata`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vicon_monitor_metadata` (
  `id` int NOT NULL DEFAULT '1',
  `ftp_host` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `monitoring_started` datetime DEFAULT NULL,
  `last_update` datetime DEFAULT NULL,
  `total_captures` int DEFAULT '0',
  `total_files` int DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `vicon_monitor_metadata_chk_1` CHECK ((`id` = 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `videoMetaData`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `videoMetaData` (
  `id` int NOT NULL AUTO_INCREMENT,
  `videoPath` varchar(255) DEFAULT NULL,
  `time` int DEFAULT NULL,
  `date` varchar(255) DEFAULT NULL,
  `tags` text,
  UNIQUE KEY `id_2` (`id`),
  KEY `id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=9699 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `woordenlijst_approvals`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `woordenlijst_approvals` (
  `id` int NOT NULL AUTO_INCREMENT,
  `woord` varchar(255) NOT NULL,
  `approved` tinyint(1) NOT NULL DEFAULT '0',
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `picked_source` varchar(50) DEFAULT NULL,
  `picked_id` varchar(50) DEFAULT NULL,
  `picked_label` varchar(255) DEFAULT NULL,
  `rerecord` tinyint(1) NOT NULL DEFAULT '0',
  `video_approved` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `woord` (`woord`)
) ENGINE=InnoDB AUTO_INCREMENT=39 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `word_request_count`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `word_request_count` (
  `id` int NOT NULL AUTO_INCREMENT,
  `session_id` varchar(36) NOT NULL,
  `word` varchar(100) NOT NULL,
  `request_count` int DEFAULT '1',
  `first_requested` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `last_requested` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_session_word` (`session_id`,`word`),
  KEY `idx_session_id` (`session_id`),
  KEY `idx_word` (`word`)
) ENGINE=InnoDB AUTO_INCREMENT=115 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `zin_api_log`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `zin_api_log` (
  `id` int NOT NULL AUTO_INCREMENT,
  `action` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `query` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `ip_address` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_agent` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `request_data` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'success',
  `error_message` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `response_time` double DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_action` (`action`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=10740917 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping events for database 'admin_gebarenoverleg'
--
/*!50106 SET @save_time_zone= @@TIME_ZONE */ ;
DELIMITER ;;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;;
/*!50003 SET character_set_client  = utf8mb4 */ ;;
/*!50003 SET character_set_results = utf8mb4 */ ;;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;;
/*!50003 SET @saved_time_zone      = @@time_zone */ ;;
/*!50003 SET time_zone             = 'SYSTEM' */ ;;
/*!50106 CREATE*/ /*!50117 DEFINER=`user`@`localhost`*/ /*!50106 EVENT `cleanup_old_metrics` ON SCHEDULE EVERY 1 DAY STARTS '2026-01-21 02:00:00' ON COMPLETION NOT PRESERVE ENABLE COMMENT 'Delete metrics older than 7 days' DO DELETE FROM client_metrics WHERE timestamp < DATE_SUB(NOW(), INTERVAL 7 DAY) */ ;;
/*!50003 SET time_zone             = @saved_time_zone */ ;;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;;
/*!50003 SET character_set_client  = @saved_cs_client */ ;;
/*!50003 SET character_set_results = @saved_cs_results */ ;;
/*!50003 SET collation_connection  = @saved_col_connection */ ;;
DELIMITER ;
/*!50106 SET TIME_ZONE= @save_time_zone */ ;

--
-- Dumping routines for database 'admin_gebarenoverleg'
--

--
-- Final view structure for view `hand_pose_similarity_search`
--

/*!50001 DROP VIEW IF EXISTS `hand_pose_similarity_search`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 SQL SECURITY INVOKER */
/*!50001 VIEW `hand_pose_similarity_search` AS select `f`.`file_id` AS `file_id`,`f`.`filename` AS `filename`,`fd`.`distance_id` AS `distance_id`,`fd`.`frame_number` AS `frame_number`,`fd`.`hand_type` AS `hand_type`,`fd`.`thumb_total_distance` AS `thumb_total_distance`,`fd`.`index_total_distance` AS `index_total_distance`,`fd`.`middle_total_distance` AS `middle_total_distance`,`fd`.`ring_total_distance` AS `ring_total_distance`,`fd`.`pinky_total_distance` AS `pinky_total_distance`,`fs`.`thumb_index_spread` AS `thumb_index_spread`,`fs`.`index_middle_spread` AS `index_middle_spread`,`fs`.`middle_ring_spread` AS `middle_ring_spread`,`fs`.`ring_pinky_spread` AS `ring_pinky_spread` from ((`hand_pose_files` `f` join `hand_pose_finger_distances` `fd` on((`f`.`file_id` = `fd`.`file_id`))) left join `hand_pose_finger_spreads` `fs` on(((`fd`.`file_id` = `fs`.`file_id`) and (`fd`.`frame_number` = `fs`.`frame_number`) and (`fd`.`hand_type` = `fs`.`hand_type`)))) where (`f`.`processing_status` = 'completed') */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-09-01 20:51:09
