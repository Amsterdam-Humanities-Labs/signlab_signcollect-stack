<?php

// Is the caller logged in on THIS host? 200 with the identity, or 401.
//
// index.html and login.html used to decide that in the browser, from any
// sessionObject cookie that parsed as JSON. On a demo under a production
// subdomain (test.signcollect.nl) the browser also sends production's
// cookie, set on the parent domain: the pages accepted it, every API
// refused it (wrong or missing signature), and login.html bounced straight
// back to the hub without ever showing the form. This asks the same
// current_session() the APIs use, so the pages and the server cannot
// disagree about who is logged in.

// signcollect-lib's install-root resolver: sc_path(), sc_dir(), sc_root().
// Vendored shim - it finds /web/lib/paths.php, or falls back to /web.
require_once __DIR__ . '/sc_paths.php';

header('Content-Type: application/json');
header('Cache-Control: no-store');

$sessionLib = sc_path('menu_beta/php_api/session.php');
if (!is_readable($sessionLib)) {
    http_response_code(503);
    echo json_encode(array('status' => 'unavailable'));
    exit;
}
require_once dirname($sessionLib) . '/db.php';
require_once $sessionLib;

$s = current_session();
if ($s === null) {
    http_response_code(401);
    echo json_encode(array('status' => 'none'));
    exit;
}
echo json_encode(array(
    'status'   => 'ok',
    'userId'   => $s['userId'],
    'username' => $s['username'],
    'role'     => $s['role'],
));
