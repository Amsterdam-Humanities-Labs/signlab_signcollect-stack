# signcollect-demovps

Deploys the `signcollect.nl` web interface onto a VPS as a fully isolated
demo instance.

Isolated means isolated: the deployed copy has no network path back to
production `signcollect.nl`, by URL rewrite *and* by firewall. See the spec
in `docs/superpowers/specs/`.

## Install a demo on a new host

One command:

    scripts/install.sh --host gomer@demo1

That is the whole thing. It takes a bare Ubuntu box to a working demo and is
equally the normal way to redeploy an already-running one - every step is
idempotent.

`--domain` is optional. The demo's hostname is read off the host itself with
`tailscale status --self`, which is the only name `tailscale cert` will issue
a certificate for anyway. On a host with no tailscale, say it yourself and
supply the certificate at `/etc/ssl/demo/<name>.{crt,key}`:

    scripts/install.sh --host gomer@demo1 --domain demo1.example.org

Nothing has a default that names a machine. A missing `--host` fails with a
usage message rather than reaching for whichever box happened to be the demo
when the script was written.

### What the host needs beforehand

1. **SSH access** as a normal user - `ssh gomer@demo1` works from here.
2. **Passwordless sudo** for that user. Everything privileged goes through
   `sudo` non-interactively.
3. **Tailscale joined and logged in**, if you want the TLS certificate and
   the derived `--domain` to work.
4. **Outbound HTTPS to github.com.** The host clones about seventeen private
   repositories itself; nothing else needs to be reachable.

Nothing else. No apache, php, mysql, git, composer or gh - `provision.sh`
installs them. `rsync` is *not* installed and is not used anywhere.

Your own `gh` login is what authorises the host: `scripts/host-auth.sh`
installs `gh` there and hands it a token from `gh auth token`. Read that
script's header before you run it on a host you do not control - the token
carries your full account scope.

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
- `scripts/_common.sh`   - shared `--host` / `--domain` handling
- `scripts/provision.sh` - LAMP, docroot, database, TLS, apache on a bare host
- `scripts/host-auth.sh` - give the host a GitHub login of its own
- `scripts/host-src.sh`  - put this repo on the host, so it can build itself
- `scripts/host-bootstrap.sh` - **runs on the host**: clone, rewrite, purge, place
- `scripts/repos.tsv`    - the interface repos and their docroot directories
- `scripts/rewrite-urls.sh` - repoint production URLs at this demo (`DOMAIN=`)
- `scripts/purge-artifacts.sh` - strip what must not ship
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

## Known gap

`signlab_signCollect-v2` and `signlab_zin` have code running on production
that was never committed - 15 and 5 files respectively, including the whole
admin section (`users.html`, `labels_add.*`, `batch_add.*`). Until those are
pushed, a GitHub-only deploy cannot reproduce production.
