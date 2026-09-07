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
 * This file DOES carry a credential, deliberately: the demo Signbank key, so
 * that a fresh checkout deploys a working connector with no manual step. It is
 * a demo key for a demo instance and is treated as public.
 *
 * The production Signbank credential must never be committed anywhere. Note
 * signbank_sync/config.production.php in signlab_signCollect-v2 already
 * violates that - it is tracked and holds a live token. That is a known leak
 * awaiting rotation, not a precedent to follow.
 *
 * A key installed at <state_dir>/.signbank_key - by scripts/host-config.sh or
 * typed into the connector page by an admin - overrides the one here at
 * runtime (key_source 'runtime'). That is how a host uses a different key
 * without editing tracked files.
 */
return [
    'base_url'         => 'https://signbank.cls.ru.nl',
    'public_url'       => 'https://signbank.cls.ru.nl',
    // The demo Signbank key, committed deliberately so a fresh checkout
    // deploys a working connector with no manual step. It is a demo key for
    // signbank.cls.ru.nl, not the production credential - that one must never
    // be committed. An admin-set key in <state_dir>/.signbank_key overrides
    // this at runtime; see signbank_config() in signbank_sync/client.php.
    'api_key'          => 'NiJzO6etgbVGgX8c',
    'auth_scheme'      => 'bearer',
    'dataset_id'       => '5',
    'dataset_acronym'  => 'NGT',
    'timeout_seconds'  => 30,

    // Enumerating a whole dataset (/dictionary/ajax/gloss/5/) takes about
    // half a minute; the per-gloss timeout above is far too short for it.
    'enumerate_timeout_seconds' => 180,

    // Everything the connector owns and may write: the runtime API key, the
    // refresh state, and the gloss dump itself. It is a directory of its own
    // because /web is not writable by www-data and replacing the dump
    // atomically needs write permission on the containing directory.
    // /web/glosses_transformed.json used to symlink in here; that link was
    // removed so a consumer reading the old path fails loudly.
    'state_dir'        => '/web/signbank_data',

    // The full refresh is spawned as a detached CLI process by the connector
    // page; under mod_php PHP_BINARY is apache2, so the interpreter is named.
    'php_cli'          => '/usr/bin/php',
];
