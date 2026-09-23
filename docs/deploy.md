# How a deploy works

What happens when you run the install, for when it goes wrong or when you are
adding something to it. The steps to type are in [install.md](install.md),
and nowhere else.

This covers demo hosts only. Production (the core server) is updated by hand:
see [production.md](production.md).

The scripts are in [`interface_deploy/`](../interface_deploy), a `git subtree`
mirror of a separate repository. Read them; change them upstream.

## The model: git-only

No built tree passes through a workstation. The host clones every component
itself, straight into its docroot directory, so `/web/<component>` **is** a git
checkout. `install.sh` only orchestrates the steps (over ssh, or in place with
`--local`).

```
workstation:  push to GitHub  ->  run install.sh (--host or --local)
host:         clone ~17 repos ->  rewrite-urls.sh -> purge -> serve
```

## What the host does per component

For every row of `scripts/repos.tsv`:

```
fetch --depth 1  ->  reset --hard  ->  clean -fd  ->  rewrite-urls.sh  ->  purge-artifacts.sh
```

`git init` + fetch + reset rather than `git clone`, because `clone` refuses a
directory that already holds files; init-and-reset adopts such a tree in place,
and `clean` removes whatever the repository no longer has. `--depth 1` because
this is a deploy, not a working copy.

`clean` spares anything the component itself gitignores (`vendor/`, `.env`,
per-repo credential files) and, explicitly, `mysql_config.php`,
`.session_secret` and `node_modules`. One exclusion is path-anchored:
`/web/zin/api` is the sCAPI mount at `/api`, not part of `signlab_zin`'s tree,
so an unguarded clean would delete it.

Then, once for the whole docroot: Composer autoloaders are dumped for any
component with a `composer.json` (today just animMIDI, whose `vendor/` is
gitignored upstream), and `mysql_config.php` is symlinked into the two
components that resolve it next to themselves rather than at the docroot.

## Why the docroot is a permanently dirty checkout

Production hostnames are baked into the source, and `rewrite-urls.sh` turns
them into same-origin paths so a deployed copy has no route back to production.
`reset --hard` puts the pristine tree back and the rewrite runs again **every
run**, because the rewrite cannot be re-applied to its own output; that is the
only way a changed `--domain` takes effect. Nobody commits from a docroot, and
Apache denies `.git` and every dotfile server-wide.

## Adding a component repo

A component is a directory under the docroot that comes from a git repository.
Adding one is a single tab-separated line in
[`scripts/repos.tsv`](../interface_deploy/scripts/repos.tsv):

```
webdir<TAB>repo<TAB>branch
```

- **`webdir`**: the directory under the webroot. Use the name production uses;
  the menu in `signlab_signCollect-v2` hardcodes `/videoFix/`, `/studioIndex/`,
  `/hh/` and the rest.
- **`repo`**: the repository name inside `Amsterdam-Humanities-Labs`.
- **`branch`**: what production has checked out. Everything is on `main`
  except `signlab_hh`, which is on `master`.

Nothing else needs changing: the bootstrap clones it, rewrites its URLs, purges
it and dumps an autoloader if it has a `composer.json`. If the repo is not
obviously in scope, say why in a comment in `repos.tsv`.

Two kinds of thing do **not** belong in `repos.tsv`:

- **Anything that is not a docroot directory.** The bootstrap knows no other
  destination, so a `pythonCron` row would publish a systemd service's source
  over HTTP. It gets `scripts/pythoncron.sh` instead and installs to
  `/opt/pythonCron`.
- **Anything with a build step.** There is none in the install, on purpose,
  which is why `signcollect-lib` ships as an ordinary component rather than a
  Composer package.

Files with no upstream repository are vendored in `interface_deploy/web_extra/`
and placed after the rewrite.

## Over ssh versus `--local`

Every step talks to the host through the `ssh` and `scp` wrappers in
`scripts/_common.sh`; `--local` replaces those two with "run it here". Anything
new must go through them, or local mode stops covering it. Two steps differ:

- **host-src**: over ssh it overlays your local `HEAD` tree onto the host's
  checkout (about 1 MB), because the subtree mirror can lag behind upstream.
  `SKIP_OVERLAY=1` turns it off. `--local` skips it and deploys exactly what the
  mirror holds; to ship an upstream change today, deploy over ssh or push the
  subtree first.
- **host-auth**: over ssh it borrows a token from your workstation's `gh`.
  Under `--local` there is no workstation to borrow from, so it runs
  `gh auth login --web` when a terminal is attached, and stops with a message
  when none is.
