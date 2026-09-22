# signcollect-demovps

Deploys the `signcollect.nl` web interface onto a VPS as a fully isolated
demo instance.

Isolated means isolated: the deployed copy has no network path back to
production `signcollect.nl`, by URL rewrite *and* by firewall. See the spec
in `docs/superpowers/specs/`.

## Quickstart

### What a brand-new host needs first

A demo host is an ordinary Ubuntu box (24.04 is what these are tested on).
Before the first install it needs exactly four things, and nothing else -
apache, php, mysql, git, composer, gh and nftables are all installed for you:

1. **A normal user you can log in as** - `ssh gomer@demo1` works, by key.
2. **Passwordless sudo for that user.** Everything privileged runs
   non-interactively, so a `sudo` that stops to ask for a password stops the
   install half way through. As root on the host:

       echo 'gomer ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/gomer
       chmod 440 /etc/sudoers.d/gomer

3. **Outbound HTTPS to github.com.** The host clones about seventeen private
   repositories itself. Nothing else needs to be reachable.
4. **Tailscale joined and logged in** - `sudo tailscale up`. That is where the
   demo's hostname and its TLS certificate come from. Without it, supply both
   yourself: `--domain <name>` and a certificate at
   `/etc/ssl/demo/<name>.{crt,key}`.

Plus GitHub credentials, which differ by mode and are the one thing the
installer cannot invent - see below.

You do not have to remember any of this. `scripts/preflight.sh` checks every
one of them, changes nothing, and prints the command that fixes each:

    scripts/preflight.sh --host gomer@demo1

### Then, the one command

**From your workstation, over ssh** - your own `gh` login is what authorises
the host, so `gh auth login` here first:

    scripts/install.sh --host gomer@demo1

**On the demo host itself, no ssh at all.** Open a terminal on the machine
and paste this, all of it at once:

    sudo apt update && sudo apt install -y git gh
    gh auth login --hostname github.com --git-protocol https --web
    gh repo clone Amsterdam-Humanities-Labs/signlab_signcollect-stack ~/signcollect-deploy
    ~/signcollect-deploy/interface_deploy/scripts/install.sh --local

The second line is the only one that needs you: it prints a one-time code and
opens the browser (or, on a machine without one, go to
<https://github.com/login/device> on any computer and type the code there).
No personal access token to create first - the stack repository is private,
and `gh` is what makes cloning it a browser login instead of a password
prompt. Ubuntu 24.04 ships `gh` in `universe`, so the plain apt line gets it.

When it finishes it prints the demo's address. Apache, php, mysql, composer
and nftables are all installed by the installer itself.

Redeploying later is the last line again. If you run `install.sh --local` on a
host that has never logged in to GitHub, it asks for that login itself at
step 3 - it only stops and tells you to run `gh auth login` first when there
is no terminal to ask on (piped, or run from another script).

That is the whole thing, in either mode. It takes a bare Ubuntu box to a
working demo at `https://<host>.<tailnet>.ts.net`, log in as `gomer` / `123`,
and it is equally the normal way to redeploy an already-running one.

### Before you commit to it

    scripts/install.sh --host gomer@demo1 --dry-run

Runs the preflight checks and then reports, from the host's actual state,
what each of the eleven steps would change - which packages are missing, how
many components are already checked out, whether the database is empty,
whether isolation has been applied. It changes nothing.

### If it stops half way

Re-run the same command. Every step is idempotent and the run resumes rather
than compounding: packages are compared against `dpkg`, the schema is loaded
only into an empty database, `.env` and `.session_secret` are written once and
then left alone, each component is `fetch` + `reset --hard` rather than a
clone that would refuse a non-empty directory, and migrations are recorded in
`schema_migrations`.

A failure names the step it stopped at, the host it was talking to, and the
command to retry - the step alone, or the whole install:

    === install FAILED at step 5/11: bootstrap - clone 17 components ===
        host: gomer@demo1 (over ssh)   webroot: /web

### The options

    --host    <target>   ssh target for the demo host          } one of
    --local              this machine IS the demo host         } these two
    --domain  <name>     what the demo is served as. Read off the host with
                         `tailscale status --self` when omitted, which is the
                         only name `tailscale cert` will issue for anyway.
    --webroot <path>     where the site is installed. Default /web. Becomes
                         apache's DocumentRoot, the parent of the /api and
                         /media mounts, and SC_WEB_ROOT in the env file, so
                         the PHP path resolver and the deploy cannot disagree.
    --no-provision       skip step 2 on a known-good server
    --dry-run            report; change nothing

Nothing has a default that names a machine. A missing `--host` fails with a
usage message rather than reaching for whichever box happened to be the demo
when the script was written.

### --local and --host are the same install

Every step talks to the host through the `ssh` and `scp` wrappers in
`scripts/_common.sh` and through nothing else; `--local` replaces those two
functions with "run it here". Anything new must go through them, or local mode
quietly stops covering it. Two steps are genuinely different rather than
merely redirected, and both say so where they happen:

- `host-src.sh` **skips entirely** under `--local`. Its job is to give a
  second machine a copy of this tree; there is no second machine, and doing
  it anyway would `git reset --hard` the checkout the running scripts are
  being read out of.
- `host-auth.sh` **cannot fabricate a login** under `--local`. Over ssh it
  hands the host a token from your workstation's `gh`; on the host itself
  there is no other account, so it installs `gh` and runs the browser login
  with you at the terminal - or, with no terminal to ask on, tells you to run
  `gh auth login` and stops.

## How a deploy works

    workstation:  push to GitHub  ->  ssh host, run the bootstrap
    host:         clone 17 repos  ->  rewrite-urls.sh  ->  purge  ->  serve

`install.sh` is an SSH orchestrator; no file of the deployed tree passes
through the workstation. The host clones each component straight into its
docroot directory, so `/web/<component>` *is* a git checkout.

The URL rewrite is why a demo is not just `git pull`. Production hostnames
are baked into the source (`https://api.signcollect.nl`,
`wss://signcollect.nl/...`), and `scripts/rewrite-urls.sh` turns them into
same-origin paths so the demo has no route back. It runs **on the host**,
between the clone and the first request, and each redeploy re-derives it from
a pristine `git reset --hard` - which is the only way a changed `--domain`
ever takes effect.

## Layout

- `scripts/install.sh`   - the entry point; orchestrates everything below
- `scripts/preflight.sh` - read-only checks of everything the install depends on
- `scripts/_common.sh`   - shared `--host` / `--domain` handling
- `scripts/provision.sh` - LAMP, docroot, database, TLS, apache on a bare host
- `scripts/host-auth.sh` - give the host a GitHub login of its own
- `scripts/host-src.sh`  - put this repo on the host, so it can build itself
- `scripts/host-bootstrap.sh` - **runs on the host**: clone, rewrite, purge, place
- `scripts/repos.tsv`    - the interface repos and their docroot directories
- `scripts/rewrite-urls.sh` - repoint production URLs at this demo (`DOMAIN=`)
- `scripts/purge-artifacts.sh` - strip what must not ship
- `scripts/fetch-ffmpeg-core.sh` - the 32MB ffmpeg.wasm core the annotation
  editor loads and no longer carries in git, hash-pinned and host-cached
- `scripts/host-config.sh` - the per-host files that are gitignored upstream
- `scripts/pythoncron.sh` - the job scheduler, at `/opt/pythonCron`
- `scripts/migrate.sh`   - apply SQL migrations from the deployed checkout
- `scripts/seed-demo-data.sh` - demo rows, and the media hard links
- `scripts/isolate.sh`   - null-route and firewall production off the demo host
- `scripts/verify.sh`    - assert the result, by command output not assumption
- `tests/`     - HTTP end-to-end suites (`BASE=https://host tests/<name>.sh`)
- `apache/`    - docroot and path-mount config for the target
- `assets/`    - the Signbank gloss dump the connector seeds from
- `web_extra/` - the parts of production that have **no upstream repo**
                 (`nmm`, `downloadVideos`, root `.html`) plus the
                 demo-only login/session files. Vendored so a fresh checkout
                 can redeploy; splitting them into real repos is tracked in
                 the stack issue tracker.
- `db/`        - schema-only dump, demo rows, demo login
- `docs/`      - design spec

Every script takes `--host` (and `--domain` where it needs one) and is
runnable on its own.

## This repo on GitHub

It has no remote of its own. Its content is mirrored as `interface_deploy/`
inside `Amsterdam-Humanities-Labs/signlab_signcollect-stack` with
`git subtree`, and that is what the host clones. Between a commit here and
that push the mirror is behind, so `scripts/host-src.sh` overlays the local
`HEAD` tree onto the host's checkout after cloning - about a megabyte, of
which nearly all is `assets/glosses_transformed.json`. When the mirror is
current it writes identical bytes; `SKIP_OVERLAY=1` turns it off.

**`--local` has no overlay, and cannot have one.** On the host there is no
second tree to overlay from - the checkout you are standing in is the one the
install uses. So a `--local` run deploys exactly what the mirror holds, and a
change made here reaches it only after the `git subtree` push. If you have just
edited something in this repository and want it on a host today, either deploy
over ssh (which overlays your working tree) or push the subtree first.
