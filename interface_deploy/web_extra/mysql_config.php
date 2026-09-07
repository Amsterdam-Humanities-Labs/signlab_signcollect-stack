<?php
// Database credentials for the demo instance.
//
// The credentials themselves are NOT here - they live in /web/.env, which is
// gitignored, never deployed, and denied by apache (see apache/signcollect-web.conf).
// This file is only the shim that loads them.
//
// It keeps the four variable names production uses, so all ~100 callers that
// `include mysql_config.php` keep working untouched. Replacing those call
// sites with a real config layer is a separate job.

$__envfile = '/web/.env';
$servername = $username = $password = $database = '';

if (!is_readable($__envfile)) {
    http_response_code(500);
    die('Configuration error: /web/.env is missing or unreadable.');
}

foreach (file($__envfile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $__line) {
    $__line = trim($__line);
    if ($__line === '' || $__line[0] === '#' || strpos($__line, '=') === false) continue;
    list($__k, $__v) = explode('=', $__line, 2);
    $__v = trim(trim($__v), "\"'");
    switch (trim($__k)) {
        case 'DB_HOST': $servername = $__v; break;
        case 'DB_USER': $username   = $__v; break;
        case 'DB_PASS': $password   = $__v; break;
        case 'DB_NAME': $database   = $__v; break;
    }
}
unset($__envfile, $__line, $__k, $__v);
