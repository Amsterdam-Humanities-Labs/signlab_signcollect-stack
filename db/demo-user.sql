-- Demo login for the isolated demovps instance.
-- login_sc.php compares `pass` in plaintext, so this matches that scheme.
-- last_login/last_activity are set to NOW() because login_sc.php auto-blocks
-- any account idle for more than 60 days.
INSERT INTO users
  (user, pass, logboek, tableCheck, lang, last_login, last_activity, last_page,
   blocked, role, default_context, default_dataset, allowed_datasets)
VALUES
  ('gomer', '123', '', '', 'eng', NOW(), NOW(), NULL,
   0, 'admin', 'signbank', 'ngt', JSON_ARRAY('ngt'))
ON DUPLICATE KEY UPDATE
  pass = '123', blocked = 0, last_login = NOW(), last_activity = NOW();
