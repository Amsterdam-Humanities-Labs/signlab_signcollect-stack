# SignCollect on demovps — isolated demo deployment

**Date:** 2026-09-01
**Status:** approved, in implementation
**Target:** demovps — `dev.taila8bdbd.ts.net` / `100.72.57.25`

## Goal

Serve the `signcollect.nl` web interface from demovps as a self-contained demo:
the same pages, backed by an empty database, with **no network path back to
production**. Mocap is excluded.

## Scope

In scope — the four destinations of the production landing page, minus mocap:

| Component | Production path | Source |
|---|---|---|
| Landing page | `/web/index.html` | rsync — no repo exists |
| signCollect v2 | `/web/menu_beta` | `signlab_signCollect-v2` |
| Legacy menu | `/web/menu_old` | rsync — no repo exists |
| Zin annotation tool | `/web/zin` | `signlab_zin` |
| Read API | `/web/zin/api` | `signlab_sCAPI` |

Out of scope: `mocap.signcollect.nl`; media files (3.2 GB); Signbank (Django
`:8889`); ISS_Server (`:9102`); handshape_search (`:3212`); scryer (`:9090`);
the ten WebSocket proxies; `/weng`; `dashboard.signcollect.nl`.

## Accepted consequences

These follow from the chosen options and are not defects:

1. **Video does not play, anywhere.** No media copied, and no production access
   to fall back on.
2. **~38 uncommitted production files are absent** — code comes from GitHub, and
   production carries uncommitted work including `users_api.php`,
   `batch_add.php`, `labels_add.php`, `get_glosses.php`.
3. **Anything calling an out-of-scope service fails.** Signbank sync, the
   WebSocket editors, and handshape search have no backend here.
4. `opnameViewTest.html` is a **dead link in production too** — the file does not
   exist. Reproduced faithfully rather than fixed.

## Topology

Tailscale issues a certificate only for the node's own MagicDNS name, so the
three production subdomains cannot become three hostnames here. Everything
collapses onto one origin with path mounts — which also removes CORS and
mixed-content concerns:

```
https://dev.taila8bdbd.ts.net/       -> /web             landing, menu_beta, menu_old, zin
https://dev.taila8bdbd.ts.net/api/   -> /web/zin/api     was api.signcollect.nl
https://dev.taila8bdbd.ts.net/media/ -> /web/media_stub  was media.signcollect.nl (404s)
```

## URL rewrite

The code carries ~155 absolute URLs to production. Left alone, the browser would
load pages from demovps and send calls — including writes — to the live site.
They are all string constants, so a scripted rewrite is tractable.

`scripts/rewrite-urls.sh`, applied after clone, in this order:

| From | To |
|---|---|
| `https://api.signcollect.nl` | `/api` |
| `https://media.signcollect.nl` | `/media` |
| `https://signcollect.nl` | `` (empty — absolute becomes same-origin relative) |

Order matters: the bare host rule runs **last** so it cannot consume the
subdomains first. Applied to `.js`, `.php`, `.html`, `.css`; excluding
`node_modules/`, `.git/`, and `docs/`.

Not rewritten: Swift client code in `zin` (`URL(string: "https://signcollect.nl/...")`).
It is not web-served, so rewriting it would be noise.

## Configuration

The repos gitignore their real configs, so these are authored fresh. None
require production secrets:

| File | Source | Contents |
|---|---|---|
| `/web/mysql_config.php` | none — untracked in production | local DB credentials |
| `/web/zin/api/mysql_config.php` | `mysql_config.example.php` | local DB credentials |
| `/web/zin/mysql_config.php` | template | local DB credentials |
| `/web/zin/.env` | `.env.example` | Discord alerts — **dummy values** |
| `/web/menu_beta/signbank_sync/config.php` | `config.example.php` | Signbank API — **dummy**, service is out of scope |

## Database

Schema only, no rows:

```
mysqldump --no-data --skip-add-drop-table --routines --events
```

97 base tables + 1 view; no routines, no triggers; **1 event** (`cleanup_old_metrics`,
a daily `DELETE` on `client_metrics` - harmless against empty tables, and the
event scheduler is off by default on demovps); 13 foreign keys. All InnoDB.
Recreated on demovps as database `admin_gebarenoverleg`, user `user`, so the
config files differ from production only in password.

Collations are mixed in production — 56 `utf8mb4_0900_ai_ci`, 23
`latin1_swedish_ci`, 17 `utf8mb4_unicode_ci`, 1 `utf8mb3_general_ci`. The dump
preserves them verbatim. `DEFINER` clauses are stripped and the view forced to
`SQL SECURITY INVOKER`, since the production definer does not exist here.
Collations are **not** normalised: the code may depend on
existing comparison behaviour, and this is a faithful-copy exercise.

Import wraps in `SET FOREIGN_KEY_CHECKS=0` so the 13 FKs do not constrain
table order.

## Isolation

Two independent layers, because a regex rewrite cannot be proven exhaustive:

1. **DNS null-route** — `signcollect.nl`, `api.`, `media.`, `mocap.` mapped to
   `127.0.0.1` in demovps `/etc/hosts`.
2. **Egress block** — nftables rule rejecting outbound traffic to production's
   IP addresses.

No carve-out for media. Anything the rewrite missed fails immediately and
visibly instead of silently reaching production.

The block is **verified empirically** — connection attempted from demovps to
production and confirmed refused — not assumed from the presence of the rules.

## Verification

Per phase, evidence required before the phase is called done:

- every in-scope page returns HTTP 200
- `grep -r "signcollect\.nl"` over the deployed tree returns **only** the
  documented Swift exclusion
- a connection attempt from demovps to production is **refused**
- `SHOW TABLES` returns 98 objects, and every table returns `COUNT(*) = 0`
- the Apache error log is clean after exercising each entry point

## Phases

**Phase 1** — landing page, `menu_beta`, database schema, isolation layer, vhost.
**Phase 2** — `zin`, `sCAPI` at `/api`, media stub.

Phase 1 is validated before Phase 2 begins; `zin` is the bulk of both the code
and the external-dependency risk.

---

# Implementation notes (2026-09-01)

Deviations and discoveries from actually building it.

## Code is cloned locally, not on demovps

`gh` is authenticated on the workstation, so the three repos are cloned there
and rsynced over. demovps needs no GitHub credentials and no outbound git
access.

## `innodb_strict_mode` must be off for the import

`form_data` is `DEFAULT CHARSET=latin1` with **68 columns** totalling ~53,295
bytes of declared varchar width, against InnoDB's ~8126-byte limit. The import
fails at that table with `ERROR 1118 Row size too large`.

This is **not** a difference between the two servers — both run
`strict_mode=1, page=16384, fmt=dynamic`, and production stores the table as
Dynamic. The table exists in production only because it was built up through
incremental `ALTER`s that each passed on their own; it cannot be recreated from
its own dump under strict mode.

The import therefore runs with `SET SESSION innodb_strict_mode=0`. DYNAMIC row
format pushes long columns off-page, which is how the table already behaves in
production. Consequence: an insert whose row genuinely exceeds the limit would
fail at runtime — irrelevant here, since every table is empty by design.

## Apache modules

`mod_rewrite` is required — `/web/zin/api/.htaccess` uses `RewriteEngine`, and
without it every `/api` request returns 500. `mod_headers` and `mod_expires` are
enabled for the same reason. None are on in a default Ubuntu install.

## Dotfiles were served

`/web/zin/.env` returned **200** on first deployment. Values were dummies, but
the exposure pattern is real. `signcollect-web.conf` now denies dotfiles,
`.git`/`.svn` directories, and `.bak/.sql/.log/.save/.orig/~` files across the
whole docroot, and `mysql_config*.php` everywhere.

## Upstream finding: a live session token in git

`signlab_sCAPI` tracks `cookies.txt` containing a real `PHPSESSID` for
`api.signcollect.nl`. `purge-artifacts.sh` removes it (with the committed test
logs and response captures) before deployment, but **it remains in the upstream
repository history** and should be rotated and purged there.

## Config file ownership

Configs are `640 gomer:www-data`. Apache runs as `www-data`; a PHP-CLI test as
`gomer` will pass even when the web server cannot read the file, so this must be
verified as `www-data`.

## Verification

`scripts/verify.sh` checks pages, secret denial, isolation, and database state
in one run. Full pass recorded 2026-09-01.

## Demo login (added 2026-09-01)

`login.html` posts to `login_sc.php`, which was **not** part of the original
deployment — it sits untracked at the production docroot root, like
`index.html` and `menu_old`, so it comes by rsync. Without it the login form
posts into a 404.

Authentication is `SELECT ... FROM users WHERE user = ? AND pass = ?`:
**passwords are compared in plaintext**. That is the upstream scheme, not a
choice made here; the demo user matches it.

`db/demo-user.sql` creates `gomer` / `123`, role `admin`, context `signbank`,
dataset `ngt` — mirroring the production account's non-secret attributes.
`last_login` and `last_activity` are set to `NOW()` because `login_sc.php`
auto-blocks any account idle more than 60 days, and a NULL/old value would make
the account unusable on arrival.

**This makes `users` the one table that is not empty** — a deliberate exception
to "empty tables only", required for the login to work at all. Every other table
remains empty.
