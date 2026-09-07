<?php
/**
 * Signbank client config for a DEMO instance.
 *
 * signbank_config() in signbank_sync/client.php throws if this file is absent
 * or if api_key is still the 'YOUR_BEARER_TOKEN_HERE' placeholder - and
 * php_api/current_user.php calls it on every page load, so without this file
 * the whole menu fails with "Init failed: Internal Server Error".
 *
 * No real credential belongs here. Signbank is a third-party service at
 * Radboud; a demo must not authenticate against it. base_url therefore points
 * at the discard port so any sync attempt fails immediately and locally
 * instead of leaving the box - the same treatment rewrite-urls.sh gives the
 * WebSocket endpoints. public_url stays real because it is only used to build
 * display links.
 */
return [
    'base_url'         => 'http://127.0.0.1:9',
    'public_url'       => 'https://signbank.cls.ru.nl',
    'api_key'          => 'demo-instance-no-signbank-access',
    'auth_scheme'      => 'bearer',
    'dataset_id'       => '5',
    'dataset_acronym'  => 'NGT',
    'timeout_seconds'  => 5,
];
