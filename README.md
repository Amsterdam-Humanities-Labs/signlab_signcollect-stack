# signcollect-demovps

Deploys the `signcollect.nl` web interface (minus mocap) onto a demo VPS as a
fully isolated demo instance. Default target is **demovps**
(`dev.taila8bdbd.ts.net`).

Isolated means isolated: the deployed copy has no network path back to
production `signcollect.nl`, by URL rewrite *and* by firewall. See the spec
in `docs/superpowers/specs/`.

## Deploy

Everything is obtained from GitHub - the component repos in
`scripts/repos.tsv` plus the vendored trees in this repo. Nothing is pulled
from production, so this runs from any checkout.

    scripts/install.sh                                  # -> demovps
    HOST=demo2 DOMAIN=demo2.example.org scripts/install.sh   # -> a new VPS

`install.sh` runs clone -> rewrite -> purge -> deploy -> apache -> verify.
The individual steps are also runnable on their own.

## Layout

- `scripts/repos.tsv` - the seven interface repos and their `/web` directories
- `scripts/clone.sh`  - fetch components from GitHub into `build/`
- `scripts/rewrite-urls.sh` - repoint production URLs at this demo (`DOMAIN=`)
- `scripts/purge-artifacts.sh`, `remove-mocap-tile.py` - strip what must not ship
- `scripts/deploy.sh` - rsync `build/` + `web_extra/` to the target (`HOST=`)
- `scripts/isolate.sh` - null-route and firewall production off the demo host
- `scripts/verify.sh`  - assert the result, by command output not assumption
- `apache/`    - docroot and path-mount config for the target
- `web_extra/` - the parts of production that have **no upstream repo**
                 (`menu_old`, `nmm`, `downloadVideos`, root `.html`) plus the
                 demo-only login/session files. Vendored so a fresh checkout
                 can redeploy; splitting them into real repos is tracked in
                 the stack issue tracker.
- `db/`        - schema-only dump (no data)
- `docs/`      - design spec

## Known gap

`signlab_signCollect-v2` and `signlab_zin` have code running on production
that was never committed - 15 and 5 files respectively, including the whole
admin section (`users.html`, `labels_add.*`, `batch_add.*`). Until those are
pushed, a GitHub-only deploy cannot reproduce production.
