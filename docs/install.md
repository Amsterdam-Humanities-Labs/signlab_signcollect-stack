# Installing SignCollect on a new host

This page takes a bare Ubuntu machine to a working SignCollect web interface.
You need no earlier knowledge of the setup, and nobody to ask.

The toolchain is [`interface_deploy/`](../interface_deploy) in this repository.
It is a `git subtree` copy of a separate repo. Read it here, but make changes
upstream. Edits committed here are lost on the next sync.

## What you get

One host that serves the interface at `https://<host>.<tailnet>.ts.net`, with:

- Apache, PHP, MySQL and the certificate, installed and configured
- the component repositories of [`scripts/repos.tsv`](../interface_deploy/scripts/repos.tsv)
  cloned into the webroot. Each docroot directory is its own git checkout
- the `admin_gebarenoverleg` schema, its migrations, a demo login
  (`gomer` / `123`) and twenty real studio recordings with their video
- `pythonCron` installed as a systemd service
- every network path from the host back to production `signcollect.nl` cut,
  by DNS null-route and by nftables

The install does not depend on production. Nothing is copied from the
production server, and production does not need to be reachable. The host
builds itself from GitHub. This also makes it safe: a firewall separates the
deployed copy from production, and its production URLs are rewritten to
same-origin paths before the first request is served.

## Before you start

A host is an ordinary Ubuntu machine. These hosts are tested on 24.04. It needs
exactly four things in advance. The install sets up everything else (apache,
php, mysql, composer, nftables). On the host itself (`--local`), you first
install `git` and `gh` with one apt line (below).

1. A normal user you can ssh in as, by key. `ssh gomer@demo1` must work.

2. Passwordless sudo for that user. Every privileged step runs without
   prompting. A `sudo` that stops to ask for a password stops the install half
   way. As root on the host:

   ```
   echo 'gomer ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/gomer
   chmod 440 /etc/sudoers.d/gomer
   ```

3. Tailscale joined and logged in: `sudo tailscale up`. The demo's hostname and
   its TLS certificate both come from Tailscale. `tailscale cert` only issues a
   certificate for the node's own MagicDNS name. That is why the installer reads
   the name from the host instead of letting you choose one. Without Tailscale
   you must supply both yourself: `--domain <name>` and a certificate at
   `/etc/ssl/demo/<name>.{crt,key}`.

   **A public name instead (for example `test.signcollect.nl`):** point its DNS
   A record at the server, keep port 80 open, and let the installer get a free
   Let's Encrypt certificate that renews itself:

       LETSENCRYPT_EMAIL=you@uva.nl scripts/install.sh --local --domain test.signcollect.nl

4. Outbound HTTPS to github.com. The host clones about seventeen private
   repositories itself. Nothing else has to be reachable.

Also check the size of the machine. It needs 3 GB of free disk. 5 GB is
comfortable: the demo media alone is 292 MB, and there are seventeen checkouts,
a database and apt's cache on top. It needs about 1 GB of RAM. With less,
`mysql-server` often does not start.

The installer cannot create a GitHub login for you. Over ssh it borrows the
`gh` login on your workstation. On the host it uses a browser login
(`gh auth login --web`), with no token.

## Check first, change nothing

You do not have to remember all of this. `preflight.sh` checks everything the
install depends on. It changes nothing, and prints the command that fixes each
failure:

```
interface_deploy/scripts/preflight.sh --host gomer@demo1
```

It checks all of this in one ssh round trip:
- that the host answers ssh at all. It tells a refused key, a name that does
  not resolve and a dead machine apart
- the OS and the user
- passwordless sudo
- that `apt-get` exists
- that github.com is reachable from the host
- whether `gh` is installed and logged in
- the domain, taken from the host's Tailscale
- `git`, `curl`, `python3` and systemd
- free disk on the nearest existing parent folder of the webroot
- RAM
- whether ports 80 and 443 are free, or held by something that is not apache
- whether the webroot already exists. This is how it tells a first install
  from a redeploy

On a deploy from your workstation it also checks your side: `ssh`, `git`,
`tar`, `gzip`, `curl`, and a logged-in `gh`.

It only reads, so it is also safe to run against a host you are unsure of.

## The one command

There are two modes. Both run the same install.

### From your workstation, over ssh

Your own `gh` login gives the host access, so log in here first:

```
gh auth login
interface_deploy/scripts/install.sh --host gomer@demo1
```

That is all.

### On the host itself, without ssh

Open a terminal on the host and paste:

```
sudo apt update && sudo apt install -y git gh
gh auth login --hostname github.com --git-protocol https --web
gh repo clone Amsterdam-Humanities-Labs/signlab_signcollect-stack ~/signcollect-deploy
~/signcollect-deploy/interface_deploy/scripts/install.sh --local
```

Line 2 shows a one-time code. Enter it at <https://github.com/login/device>.
You do not need a personal access token. Tested on a bare Ubuntu 24.04 host
(`stijn`): about 3.5 minutes to a verified demo.

### Shortcuts

`interface_deploy/Makefile` wraps the same scripts. Run it from `interface_deploy/`:
`make install` (on the host), `make install HOST=gomer@demo1` (over ssh),
`make dry-run`, `make preflight`, `make verify`, `make test`.

### See what it would do first

```
interface_deploy/scripts/install.sh --host gomer@demo1 --dry-run
```

This runs preflight. Then it reads the host as it is now and reports what each
of the eleven steps would change: which packages are missing, how many
components are already checked out, whether the database is empty, and whether
isolation is already in place. It changes nothing. Only `install.sh` supports
`--dry-run`. The other scripts refuse it instead of pretending.

## The flags

| Flag | What it does |
|---|---|
| `--host <ssh-target>` | The machine to deploy to, e.g. `gomer@demo1`. You must give this or `--local`. |
| `--local` | This machine is the host. Runs everything here, without ssh. |
| `--domain <name>` | The name the site is served as. Optional: by default it is read from the host with `tailscale status --self`, which is the only name a Tailscale certificate can have anyway. It ends up in cookie domains and in the redirect allow-lists of `login.html` / `logout.html`. A wrong value deploys without errors and serves pages, but then silently refuses every login. |
| `--webroot <path>` | Absolute path to install into. Default `/web`. It becomes Apache's `DocumentRoot`, the parent of the `/api` and `/media` mounts, and `SC_WEB_ROOT` in the env file. So the PHP path resolver and the deploy always agree. Choose it at install time. Moving it later means moving the tree and running the install again with the new value. |
| `--no-provision` | Skip step 2 on a server you know is already set up. |
| `--dry-run` | Report what would change. Change nothing. |

`HOST` and `DOMAIN` also work as environment variables. No flag has a default
that names a machine. Without `--host`, the script stops with a usage message.
It does not fall back to whichever machine was the demo when the script was
written.

## What the eleven steps do

1. preflight: everything above. Nothing changes until it passes.
2. provision: apt packages (apache2, php and its modules, mysql-server, git,
   curl, nftables, composer, python3-psutil), the webroot, the database and
   its password in `.env`, a `tailscale cert`, and the Apache vhost.
3. host-auth: gives the host a GitHub login. Over ssh: a token from the `gh`
   on your workstation. It has full account scope and is stored in
   `~/.config/gh/hosts.yml` on the host. Revoke it if the host is lost. With
   `--local`: if `gh` is not logged in and a terminal is attached, it runs
   `gh auth login --web`. Without a terminal it stops and says so.
4. host-src: puts this deploy tree on the host, at `~/signcollect-deploy`.
   Skipped with `--local`: there is no second machine, and running it would
   reset the checkout that the running scripts are read from.
5. bootstrap: runs on the host. Clones every component, rewrites the
   production URLs, removes what must not ship, and puts the vendored files in
   place. [deploy.md](deploy.md) explains this in detail.
6. isolate: null-routes production in `/etc/hosts` and loads nftables reject
   rules. Production is reachable both publicly and as a tailnet peer, so both
   are blocked. The chain policy stays `ACCEPT` and only production's
   addresses are rejected, so it cannot cut your own ssh.
7. host-config: the files each host needs that are gitignored upstream, so a
   clone never brings them: `.session_secret` and the Signbank gloss dump. It
   also creates the data directories kept outside the checkouts:
   `annotation_data/clusters` and `videofix_data`. It never overwrites a file
   that already exists.
8. pythoncron: the job scheduler, cloned to `/opt/pythonCron` and installed as
   a systemd service. A failure here does not stop the install: a demo without
   a scheduler is still a demo. Set `PYTHONCRON_BRANCH` to install another
   branch, for example to test a pull request.
9. migrate: SQL migrations, read from the deployed `menu_beta` checkout, so
   they always match the code being served. Applied migrations are recorded in
   `schema_migrations`, so running it again is safe.
10. seed: the demo rows, and the hard links into `media_stub`. The video
    itself is an ordinary component now (`signlab_demo-media`), so step 5 has
    already cloned it. A failure here does not stop the install.
11. verify: checks the result. See below.

## If it stops half way

Run the same command again. Every step is idempotent, and a second run finishes
the job instead of doing it twice:
- packages are compared against `dpkg`
- the schema is only loaded into an empty database
- `.env` and `.session_secret` are written once and then left alone
- each component uses `fetch` + `reset --hard`, not a clone that would refuse
  a non-empty directory
- migrations are guarded by `schema_migrations`

A failure names the step it stopped at, the host it was talking to, and the
command to retry:

```
=== install FAILED at step 5/11: bootstrap - clone 17 components ===
    host: gomer@demo1 (over ssh)   webroot: /web
```

Running the install again is also the normal way to redeploy a running host.

## Checking the result

`verify.sh` is the first check. Every check in it is a command whose output you
can read:

```
interface_deploy/scripts/verify.sh --host gomer@demo1 https://demo1.example.ts.net
```

It checks that:
- the pages and component entry points return 200
- `/stats.html` is gone and stays gone
- the Signbank gloss dump is served
- every secret (`mysql_config.php`, `.env`) and the data files in
  `annotation_data/` and `videofix_data/` return 403
- production cannot be reached from the host
- `gomer` / `123` can log in, and a wrong password cannot
- the database holds its 99 objects

There are also six end-to-end test suites in
[`interface_deploy/tests/`](../interface_deploy/tests). Each takes the base URL
in `BASE`. They write data, so they refuse to run against production:

| Suite | What it tests |
|---|---|
| `interface-test.sh` | The HTTP endpoints the browser calls (login, session, users, labels, glosses, notes) and role separation: every admin action is repeated as a normal user, and must be refused. |
| `lib-test.sh` | `signcollect-lib` at `/web/lib`: that it is deployed, that nothing under it can be served, and that its first consumers read it. |
| `mocap-test.sh` | The mocap portal and everything it reaches, and that adding mocap back opened no path to production. |
| `path-test.sh` | The install-root resolver (`paths.php` and the vendored `sc_paths.php` shim), including that `SC_WEB_ROOT` can really be configured. |
| `pythoncron-test.sh` | The two things no clone can supply: animMIDI's Composer autoloader, and pythonCron installed as a service. |
| `signbank-test.sh` | The Signbank connector: admin-only access, checked three ways, and that the stored API key is never served or sent back. |

Run one like this:

```
BASE=https://demo1.example.ts.net interface_deploy/tests/interface-test.sh
```

Two of them (`path-test.sh`, `pythoncron-test.sh`) also need `HOST`, because
they check things over ssh that HTTP cannot see.

## Current hosts

| Host | Webroot | Command |
|---|---|---|
| `dev2` (current demo) | `/web` | `scripts/install.sh --host gomer@dev2` |
| `stijn` (test, `stijn.taila8bdbd.ts.net`, bare Ubuntu 24.04) | `/web` | `scripts/install.sh --local` on the host |
| `dev-1` | `/srv/signcollect/web` | `scripts/install.sh --host gomer@dev-1 --webroot /srv/signcollect/web` |

`dev-1` is the reason `--webroot` exists. It is also the reason the PHP code
finds its install root through `signcollect-lib`, instead of having `/web` in
232 string literals.
