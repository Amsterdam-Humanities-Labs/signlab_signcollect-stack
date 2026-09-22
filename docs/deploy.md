# How a deploy works

This page explains what the install does. Read it when a deploy goes wrong, or
when you add something to it. The commands to type are in
[install.md](install.md) and nowhere else.

The scripts are in [`interface_deploy/`](../interface_deploy). It is a
`git subtree` copy of a separate repository. Read the scripts here, but change
them upstream.

## Git only

No built tree passes through a workstation. The host clones every component
itself, straight into its docroot directory. So `/web/<component>` is a git
checkout. `install.sh` only runs the steps in order, over ssh or in place with
`--local`.

```
workstation:  push to GitHub  ->  run install.sh (--host or --local)
host:         clone ~17 repos ->  rewrite-urls.sh -> purge -> serve
```

## What the host does for each component

For every row of `scripts/repos.tsv`:

```
fetch --depth 1  ->  reset --hard  ->  clean -fd  ->  rewrite-urls.sh  ->  purge-artifacts.sh
```

The host uses `git init`, fetch and reset instead of `git clone`. `clone`
refuses a directory that already holds files. Init and reset take over such a
tree in place, and `clean` removes whatever the repository no longer has.
`--depth 1` is enough, because this is a deploy and not a working copy.

`clean` keeps anything the component itself gitignores (`vendor/`, `.env`,
credential files per repo). It also explicitly keeps `mysql_config.php`,
`.session_secret` and `node_modules`. One exclusion is anchored to a path:
`/web/zin/api` is the sCAPI mount at `/api` and not part of the tree of
`signlab_zin`. A clean without that guard would delete it.

Then, once for the whole docroot:
- Composer autoloaders are generated for every component with a
  `composer.json`. Today that is only animMIDI, whose `vendor/` is gitignored
  upstream.
- `mysql_config.php` is symlinked into the two components that look for it next
  to themselves instead of at the docroot.

## Why the docroot is always a modified checkout

Production hostnames are written into the source. `rewrite-urls.sh` turns them
into same-origin paths, so a deployed copy has no route back to production.
Every run, `reset --hard` restores the original tree and the rewrite runs again.
The rewrite cannot be applied twice to its own output, and this is the only way
a changed `--domain` takes effect. Nobody commits from a docroot. Apache denies
`.git` and every dotfile on the whole server.

## Adding a component repo

A component is a directory under the docroot that comes from a git repository.
To add one, add a single tab-separated line to
[`scripts/repos.tsv`](../interface_deploy/scripts/repos.tsv):

```
webdir<TAB>repo<TAB>branch
```

- `webdir`: the directory under the webroot. Use the name production uses. The
  menu in `signlab_signCollect-v2` hardcodes `/videoFix/`, `/studioIndex/`,
  `/hh/` and the rest.
- `repo`: the repository name inside `Amsterdam-Humanities-Labs`.
- `branch`: the branch production has checked out. Everything is on `main`
  except `signlab_hh`, which is on `master`.

Nothing else needs to change. The bootstrap clones the repo, rewrites its URLs,
purges it, and generates an autoloader if it has a `composer.json`. If it is not
obvious why the repo is in scope, explain it in a comment in `repos.tsv`.

Two kinds of repo do not belong in `repos.tsv`:

- Anything that is not a docroot directory. The bootstrap has no other
  destination, so a `pythonCron` row would publish the source of a systemd
  service over HTTP. pythonCron uses `scripts/pythoncron.sh` instead and
  installs to `/opt/pythonCron`.
- Anything with a build step. The install has no build step, on purpose. That
  is why `signcollect-lib` ships as an ordinary component and not as a
  Composer package.

Files with no upstream repository are kept in `interface_deploy/web_extra/`
and put in place after the rewrite.

## Over ssh or with `--local`

Every step talks to the host through the `ssh` and `scp` wrappers in
`scripts/_common.sh`. `--local` replaces those two with "run it here". New
steps must use these wrappers too, or local mode will not cover them. Two steps
work differently:

- host-src: over ssh, it copies your local `HEAD` tree over the host's checkout
  (about 1 MB), because the subtree copy can be behind upstream.
  `SKIP_OVERLAY=1` turns this off. `--local` skips this step and deploys exactly
  what the subtree copy holds. To ship an upstream change today, deploy over
  ssh or push the subtree first.
- host-auth: over ssh, it borrows a token from the `gh` on your workstation.
  With `--local` there is no workstation to borrow from. It runs
  `gh auth login --web` when a terminal is attached, and stops with a message
  when none is.
