# Installing SignCollect on a new host

How to take a bare Ubuntu box to a working SignCollect web interface, with no
prior knowledge of this estate and nobody to ask.

The toolchain is [`interface_deploy/`](../interface_deploy) in this repository.
It is a `git subtree` mirror of a separate repo — read it freely, but make
changes upstream, because edits committed here are lost on the next sync.

## What you end up with

One host serving the interface at `https://<host>.<tailnet>.ts.net`:

- Apache, PHP, MySQL and the certificate, installed and configured
- the component repositories of [`scripts/repos.tsv`](../interface_deploy/scripts/repos.tsv)
  cloned into the webroot, each docroot directory being its own git checkout
- the `admin_gebarenoverleg` schema, its migrations, a demo login
  (`gomer` / `123`) and twenty real studio recordings with their video
- `pythonCron` installed as a systemd service
- every network path from the host back to production `signcollect.nl` cut,
  by DNS null-route and by nftables

The install is **production-independent**. Nothing is copied off the
production server, and nothing needs production to be reachable — the host
builds itself from GitHub. That is also why it is safe: the deployed copy is
firewalled away from production and its production URLs are rewritten to
same-origin paths before the first request is served.

## Before you start

A host is an ordinary Ubuntu box — 24.04 is what these are tested on. It needs
exactly four things beforehand. Everything else (apache, php, mysql, git,
composer, `gh`, nftables) is installed for you.

1. **A normal user you can ssh in as, by key.** `ssh gomer@demo1` must work.

2. **Passwordless sudo for that user.** Everything privileged runs
   non-interactively, so a `sudo` that stops to ask for a password stops the
   install half way through. As root on the host:

   ```
   echo 'gomer ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/gomer
   chmod 440 /etc/sudoers.d/gomer
   ```

3. **Tailscale joined and logged in** — `sudo tailscale up`. The demo's
   hostname and its TLS certificate both come from there: `tailscale cert`
   issues for a node's own MagicDNS name and nothing else, which is why the
   installer reads the name off the host rather than letting you invent one.
   Without tailscale you must supply both yourself — `--domain <name>` and a
   certificate at `/etc/ssl/demo/<name>.{crt,key}`.

4. **Outbound HTTPS to github.com.** The host clones about seventeen private
   repositories itself. Nothing else has to be reachable.

Also worth knowing before you pick a box: it wants **3 GB of free disk**
(5 GB is comfortable — the demo media alone is 291 MB, and there are
seventeen checkouts, a database and apt's cache on top) and **about 1 GB of
RAM**, below which `mysql-server` tends not to start.

The one thing the installer cannot invent is a **GitHub login**, and what it
needs differs by mode — see below.

## Check first, change nothing

You do not have to remember any of that. `preflight.sh` asks the host every
question the install depends on, changes nothing, and prints the command that
fixes each failure:

```
interface_deploy/scripts/preflight.sh --host gomer@demo1
```

It checks, in one ssh round trip: that the host answers ssh at all (and
distinguishes a refused key from an unresolvable name from a dead box);
the OS and the user; passwordless sudo; that `apt-get` exists; that
github.com is reachable *from the host*; whether `gh` is there and logged in;
the domain, derived from the host's tailscale; `git`, `curl`, `python3` and
systemd; free disk on the nearest existing ancestor of the webroot; RAM;
whether ports 80 and 443 are free or held by something that is not apache;
and whether the webroot already exists, which is how it tells a first install
from a redeploy. On a workstation deploy it also checks your own side: `ssh`,
`git`, `tar`, `gzip`, `curl`, and a logged-in `gh`.

Because it is read-only, it is also the safe thing to run against a host you
are unsure of.

## The one command

There are two modes, and they are the same install.

### From your workstation, over ssh

Your own `gh` login is what authorises the host, so log in here first:

```
gh auth login
interface_deploy/scripts/install.sh --host gomer@demo1
```

That is the whole thing.

### On the host itself, no ssh at all

Here the host needs a GitHub login of its own, because there is no
workstation to take a token from — and it needs `git` before it can fetch the
installer that would otherwise have installed it. That is the one bootstrap
this mode cannot avoid, and it is four commands:

```
sudo apt update && sudo apt install -y git
git clone https://github.com/Amsterdam-Humanities-Labs/signlab_signcollect-stack ~/signcollect-deploy
    # a private repo: git asks for your GitHub username and, as the password,
    # a personal access token with `repo` scope
cd ~/signcollect-deploy/interface_deploy

scripts/host-auth.sh --local    # installs gh (it is not in Ubuntu's archive)
gh auth login                   # your own GitHub account
scripts/install.sh --local
```

### See what it would do, first

```
interface_deploy/scripts/install.sh --host gomer@demo1 --dry-run
```

Runs preflight and then reports, read off the host as it is right now, what
each of the eleven steps would change: which packages are missing, how many
components are already checked out, whether the database is empty, whether
isolation has been applied. It changes nothing. `--dry-run` is implemented by
`install.sh` alone; the other scripts refuse it rather than pretend.

## The flags

| Flag | What it does |
|---|---|
| `--host <ssh-target>` | The machine to deploy to, e.g. `gomer@demo1`. One of this or `--local` is required. |
| `--local` | This machine **is** the host; run everything here, no ssh. |
| `--domain <name>` | The name the site is served as. Optional: read off the host with `tailscale status --self`, which is the only name a tailscale certificate can have anyway. It lands in cookie domains and in the redirect allow-lists of `login.html` / `logout.html`, so a wrong value deploys cleanly, serves pages, and then silently refuses to sign anyone in. |
| `--webroot <path>` | Absolute path to install into. Default `/web`. Becomes Apache's `DocumentRoot`, the parent of the `/api` and `/media` mounts, and `SC_WEB_ROOT` in the env file — so the PHP path resolver and the deploy cannot disagree. Choose it at install time; moving it later means moving the tree and re-running with the new value. |
| `--no-provision` | Skip step 2 on a server you know is already good. |
| `--dry-run` | Report what would change; change nothing. |

`HOST` and `DOMAIN` are honoured as environment variables too. **Nothing has a
default that names a machine.** A missing `--host` fails with a usage message
rather than reaching for whichever box happened to be the demo when the script
was written.

## What the eleven steps do

1. **preflight** — everything above. Nothing is touched until it passes.
2. **provision** — apt packages (apache2, php and its modules, mysql-server,
   git, curl, nftables, composer, python3-psutil), the webroot, the database
   and its password in `.env`, a `tailscale cert`, the Apache vhost.
3. **host-auth** — gives the host a GitHub login. Over ssh it hands over a
   token from your workstation's `gh`; under `--local` it installs `gh` and
   stops, because there is no other account to borrow from. Note the trade:
   that token carries your full account scope, and `gh` stores it on the host
   at `~/.config/gh/hosts.yml`. Revoke it if a host is ever lost.
4. **host-src** — puts this deploy tree where the host can read it,
   at `~/signcollect-deploy`. Skipped entirely under `--local`: there is no
   second machine, and doing it anyway would reset the checkout the running
   scripts are being read out of.
5. **bootstrap** — runs on the host: clone every component, rewrite the
   production URLs, purge what must not ship, place the vendored files. See
   [deploy.md](deploy.md) for what that means in detail.
6. **isolate** — null-routes production in `/etc/hosts` and loads nftables
   reject rules. Production is reachable both publicly and as a tailnet peer,
   so both are blocked. The chain policy stays `ACCEPT` and only production's
   addresses are rejected, so it cannot cut your own ssh.
7. **host-config** — the per-host files that are gitignored upstream and so
   never arrive with a clone: `.session_secret`, the Signbank gloss dump.
   Never overwrites a file that is already there.
8. **pythoncron** — the job scheduler, cloned to `/opt/pythonCron` as a
   systemd service. Not fatal if it fails: a demo whose scheduler did not
   install is still a demo.
9. **migrate** — SQL migrations, read out of the deployed `menu_beta`
   checkout so they always match the code being served. Applied migrations
   are recorded in `schema_migrations`, so re-running is safe.
10. **seed** — the demo rows, and the hard links into `media_stub`. The video
    itself is an ordinary component now (`signlab_demo-media`), so step 5 has
    already cloned it. Not fatal.
11. **verify** — asserts the result. See below.

## If it stops half way

Re-run the same command. **Every step is idempotent and a second run
converges rather than compounding:** packages are compared against `dpkg`,
the schema is loaded only into an empty database, `.env` and
`.session_secret` are written once and then left alone, each component is
`fetch` + `reset --hard` rather than a clone that would refuse a non-empty
directory, and migrations are guarded by `schema_migrations`.

A failure names the step it stopped at, the host it was talking to, and the
command to retry:

```
=== install FAILED at step 5/11: bootstrap - clone 17 components ===
    host: gomer@demo1 (over ssh)   webroot: /web
```

This is also the normal way to redeploy a host that is already running.

## Verifying afterwards

`verify.sh` is the first check, and every claim in it is a command whose
output you can read rather than an assumption:

```
interface_deploy/scripts/verify.sh --host gomer@demo1 https://demo1.example.ts.net
```

It asserts the pages and component entry points answer 200, that
`/stats.html` is gone and stays gone, that the Signbank gloss dump is
served, that every secret (`mysql_config.php`, `.env`) is 403, that
production is unreachable *from the host*, that `gomer` / `123` authenticates
and a wrong password does not, and that the database holds its 99 objects.

Beyond that there are six end-to-end suites under
[`interface_deploy/tests/`](../interface_deploy/tests). Each takes the base
URL in `BASE` and refuses to run against production, because they write:

| Suite | What it covers |
|---|---|
| `interface-test.sh` | The HTTP surface the browser calls — login, session, users, labels, glosses, notes — and role separation: every admin action repeated as a normal user, and refused. |
| `lib-test.sh` | `signcollect-lib` at `/web/lib`: that it is deployed, that nothing under it is servable, and that its first consumers read it. |
| `mocap-test.sh` | The mocap portal and everything it reaches, and that re-admitting mocap opened no path back to production. |
| `path-test.sh` | The install-root resolver — `paths.php` and the vendored `sc_paths.php` shim — including that `SC_WEB_ROOT` really is configurable. |
| `pythoncron-test.sh` | The two things no clone can supply: animMIDI's Composer autoloader, and pythonCron installed as a service. |
| `signbank-test.sh` | The Signbank connector: admin-only access checked three ways, and that the stored API key is never served or echoed back. |

Run one like this:

```
BASE=https://demo1.example.ts.net interface_deploy/tests/interface-test.sh
```

Two of them (`path-test.sh`, `pythoncron-test.sh`) also want `HOST`, because
they check things over ssh that HTTP cannot see.

## The hosts that run this today

| Host | Webroot | Command |
|---|---|---|
| `dev2` | `/web` | `scripts/install.sh --host gomer@dev2` |
| `dev-1` | `/srv/signcollect/web` | `scripts/install.sh --host gomer@dev-1 --webroot /srv/signcollect/web` |

`dev-1` is the reason `--webroot` exists, and the reason the estate's PHP
resolves its install root through `signcollect-lib` instead of writing `/web`
into 232 string literals.
