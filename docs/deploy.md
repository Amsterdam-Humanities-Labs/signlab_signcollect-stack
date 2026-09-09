# How a deploy works

[install.md](install.md) is what to type. This is what happens when you type
it, which is what you need when it goes wrong or when you are adding
something to it.

The scripts are in [`interface_deploy/`](../interface_deploy), a `git subtree`
mirror of a separate repository. Read them; change them upstream.

## The model: git-only

There is no rsync anywhere, and no built tree passes through a workstation.

```
workstation:  push to GitHub  ->  ssh host, run the bootstrap
host:         clone ~17 repos ->  rewrite-urls.sh -> purge -> serve
```

`install.sh` is an ssh orchestrator and nothing else. The host clones each
component straight into its docroot directory, so `/web/<component>` **is** a
git checkout.

It used to work the other way: clone seventeen repositories on a workstation,
rewrite them there, rsync 500 MB up on every run. Three things were wrong with
that, and cloning on the host fixes all three at once.

- **rsync.** The current demo hosts do not have it and are not going to.
- **macOS is case-insensitive.** `signlab_hh` tracks both
  `vitamine-D.json` and `vitamine-d.json`; a checkout on a Mac silently
  collapsed each pair, so 7659 of 7661 files were ever deployed and nobody
  could see which two were missing. Cloning on Linux is a fix that cannot
  regress.
- **A single point of failure.** Only the owner of that workstation could
  deploy at all.

## What the host does per component

For every row of `scripts/repos.tsv`:

```
fetch --depth 1  ->  reset --hard  ->  clean -fd  ->  rewrite-urls.sh  ->  purge-artifacts.sh
```

`git init` + fetch + reset rather than `git clone`, because on a host that was
previously deployed by rsync the directory already exists and is full of files,
and `clone` refuses a non-empty target. Init-and-reset adopts such a tree in
place, and the `clean` afterwards removes whatever the repository no longer
has — the `rsync --delete` this replaces, said in the only vocabulary the host
now needs. `--depth 1` because this is a deploy, not a working copy.

`clean` spares anything the component itself gitignores (`vendor/`, `.env`,
per-repo credential files) and, explicitly, `mysql_config.php`,
`.session_secret` and `node_modules`. One exclusion is path-anchored and
applied only to the component it is about: `/web/zin/api` is the sCAPI service
mounted at `/api` by Apache, not part of `signlab_zin`'s tree, so an unguarded
clean would delete a working API.

Then, once for the whole docroot: Composer autoloaders are dumped for any
component with a `composer.json` (today just animMIDI, whose `vendor/` is
gitignored upstream, so nine entry points 500 without it), and
`mysql_config.php` is symlinked into the two components that resolve it next
to themselves rather than at the docroot.

## Why the docroot is a permanently dirty checkout

Production hostnames are baked into the source — `https://api.signcollect.nl`,
`wss://signcollect.nl/...` — and `rewrite-urls.sh` turns them into same-origin
paths so a deployed copy has no route back. That rewrite is the entire reason a
copy step ever existed between git and the docroot: a plain `git pull` would
serve production URLs, which is exactly what `isolate.sh` and `verify.sh` exist
to prevent.

So the ordering is deliberate. `reset --hard` puts the pristine,
production-URL tree on disk and the rewrite immediately replaces it, **every
run**. The rewrite is not re-appliable to its own output — nothing matching
`signcollect.nl` is left after the first pass — so re-deriving it from a
known-clean tree is the only way a changed `--domain` ever takes effect. The
checkout is left dirty for good, and that is fine: nobody commits from a
docroot. `.git` inside the docroot is safe because the Apache config denies
`<DirectoryMatch "/\.(git|svn)">` and any dotfile, server-wide.

## Redeploying

Re-run the install. It is the same command, every step is idempotent, and it
is also how you resume a run that stopped half way:

```
interface_deploy/scripts/install.sh --host gomer@demo1
```

On a server you know is good, `--no-provision` skips the apt and TLS step.
Every script is also runnable on its own with the same `--host` / `--domain` /
`--webroot` flags, so you can re-run just the step that failed.

## Adding a component repo

A component is a directory under the docroot that comes from a git repository.
Adding one is a single tab-separated line in
[`scripts/repos.tsv`](../interface_deploy/scripts/repos.tsv):

```
webdir<TAB>repo<TAB>branch
```

- **`webdir`** is the directory under the webroot, and it is not free choice:
  the deployed tree is kept path-identical to production, because the menu in
  `signlab_signCollect-v2` hardcodes `/videoFix/`, `/studioIndex/`, `/hh/` and
  the rest. Use the name production uses.
- **`repo`** is the repository name inside `Amsterdam-Humanities-Labs`.
- **`branch`** is what production actually has checked out. Everything is on
  `main` except `signlab_hh`, which is on `master`.

Nothing else needs changing: the bootstrap clones it, rewrites its URLs,
purges it and — if it has a `composer.json` — dumps an autoloader for it. Put
the row where a reader would look for it, and if the repo is not obviously in
scope, say in a comment why it is there. That file is already as much
explanation as data, deliberately.

Two shapes of thing do **not** belong in `repos.tsv`:

- **Anything that is not a docroot directory.** `repos.tsv` maps a repo to
  `$WEBROOT/<webdir>` and the bootstrap knows no other destination, so a row
  for `pythonCron` would clone a systemd service into the docroot and publish
  its source over HTTP. It gets `scripts/pythoncron.sh` instead, and installs
  to `/opt/pythonCron`.
- **Anything with a build step.** There is none anywhere in the install, on
  purpose. A dependency that needs `composer install` on the host is a deploy
  that 500s until somebody remembers a step no script performs — which is why
  `signcollect-lib` ships as an ordinary component rather than as a Composer
  package.

Files that have no upstream repository at all live vendored in
`interface_deploy/web_extra/` and are placed after the rewrite. Splitting those
into real repositories is tracked in this repo's issues.

## The workstation overlay, and why `--local` has none

Over ssh, `host-src.sh` overlays your local `HEAD` tree onto the host's
checkout after cloning — about a megabyte — because between a commit in the
upstream deploy repo and its `git subtree` push into this one, the mirror is
behind. When the mirror is current it writes identical bytes. `SKIP_OVERLAY=1`
turns it off.

`--local` cannot have an overlay: on the host there is no second tree to
overlay from, since the checkout you are standing in is the one the install
uses. So a `--local` run deploys exactly what the mirror holds. If you have
just changed something upstream and want it on a host today, deploy over ssh
or push the subtree first.

## One seam, and why it matters

Every step talks to the host through the `ssh` and `scp` wrappers in
`scripts/_common.sh` and through nothing else; `--local` replaces those two
functions with "run it here". Anything new must go through them, or local mode
quietly stops covering it. Only two steps are genuinely different rather than
merely redirected, and both say so where they happen: `host-src.sh` is skipped,
and `host-auth.sh` cannot fabricate a login.

## Known gap

`signlab_signCollect-v2` and `signlab_zin` have code running on production that
was never committed — 15 and 5 files respectively, including the whole admin
section (`users.html`, `labels_add.*`, `batch_add.*`). Until those are pushed,
a GitHub-only deploy cannot reproduce production exactly. The demo covers them
from `web_extra/`; a production rebuild would not.
