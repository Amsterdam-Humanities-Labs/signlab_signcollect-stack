<?php
/**
 * Signbank client config for a DEMO instance.
 *
 * signbank_config() in signbank_sync/client.php reads this file, and
 * php_api/current_user.php calls it on every page load, so a host without it
 * fails with "Init failed: Internal Server Error". It is gitignored upstream
 * and therefore never arrives with a clone; scripts/host-config.sh installs
 * this copy.
 *
 * base_url used to point at the discard port (127.0.0.1:9) so that a demo
 * could not talk to a third party at all. That changed when the interface
 * grew a Signbank connector: the gloss dump every component reads
 * (/web/glosses_transformed.json) is built by fetching ~7.5k glosses from
 * signbank.cls.ru.nl, and a connector that cannot reach Signbank is a
 * connector that cannot be demonstrated. signbank.cls.ru.nl is a Radboud
 * service, unrelated to signcollect.nl, and scripts/isolate.sh does not and
 * should not block it - the isolation that matters is from the production
 * instance, not from the outside world.
 *
 * There is still no credential in this file, and there must never be one:
 * it is tracked in git. api_key stays an inert placeholder that
 * signbank_config() recognises as "no key" (key_source 'none'), which makes
 * the connector page say so rather than send nonsense to Signbank. The real
 * key is installed separately by scripts/host-config.sh into
 * <state_dir>/.signbank_key, outside the repo and outside apache's served
 * set, or typed into the connector page by an admin.
 */
return [
    'base_url'         => 'https://signbank.cls.ru.nl',
    'public_url'       => 'https://signbank.cls.ru.nl',
    'api_key'          => 'demo-instance-no-signbank-access',
    'auth_scheme'      => 'bearer',
    'dataset_id'       => '5',
    'dataset_acronym'  => 'NGT',
    'timeout_seconds'  => 30,

    // Enumerating a whole dataset (/dictionary/ajax/gloss/5/) takes about
    // half a minute; the per-gloss timeout above is far too short for it.
    'enumerate_timeout_seconds' => 180,

    // Everything the connector owns and may write: the runtime API key, the
    // refresh state, and the gloss dump itself (/web/glosses_transformed.json
    // is a symlink into here, because /web is not writable by www-data and an
    // atomic rename needs write permission on the directory).
    'state_dir'        => '/web/signbank_data',

    // The full refresh is spawned as a detached CLI process by the connector
    // page; under mod_php PHP_BINARY is apache2, so the interpreter is named.
    'php_cli'          => '/usr/bin/php',
];
