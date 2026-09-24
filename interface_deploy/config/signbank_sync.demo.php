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
 * This file carries no credential. The Signbank key comes from
 * SIGNBANK_API_KEY (environment or the gitignored secrets.env), which
 * scripts/host-config.sh installs at <state_dir>/.signbank_key, or an admin
 * types it into the connector page. Either overrides the placeholder here at
 * runtime (key_source 'runtime'). Never commit a key: these repos are public.
 */
return [
    'base_url'         => 'https://signbank.cls.ru.nl',
    'public_url'       => 'https://signbank.cls.ru.nl',
    // Not a key: the inert placeholder signbank_key_placeholders() knows, so
    // page loads work before a key is installed (see the header).
    'api_key'          => 'demo-instance-no-signbank-access',
    'auth_scheme'      => 'bearer',
    'dataset_id'       => '5',
    'dataset_acronym'  => 'NGT',
    'timeout_seconds'  => 30,

    // Enumerating a whole dataset (/dictionary/ajax/gloss/5/) takes about
    // half a minute; the per-gloss timeout above is far too short for it.
    'enumerate_timeout_seconds' => 180,

    // Everything the connector owns and may write: the runtime API key, the
    // refresh state, and the gloss dump itself. It is a directory of its own
    // because @WEBROOT@ is not writable by www-data and replacing the dump
    // atomically needs write permission on the containing directory.
    // @WEBROOT@/glosses_transformed.json used to symlink in here; that link was
    // removed so a consumer reading the old path fails loudly.
    // @WEBROOT@ is substituted by scripts/host-config.sh when it installs this
    // file, the same way config/pythoncron.demo.json carries the docroot. It
    // was a literal /web until the first --webroot install, where everything
    // the connector owns - the runtime key, the refresh state, the lock and
    // the dump - was still being written to a directory on the wrong side of
    // the host. The demo deployed, served every page, and answered the
    // connector's every write with "cannot create /web/signbank_data".
    'state_dir'        => '@WEBROOT@/signbank_data',

    // The full refresh is spawned as a detached CLI process by the connector
    // page; under mod_php PHP_BINARY is apache2, so the interpreter is named.
    'php_cli'          => '/usr/bin/php',
];
