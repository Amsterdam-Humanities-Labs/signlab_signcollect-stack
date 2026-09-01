# signcollect-demovps

Deploys the `signcollect.nl` web interface (minus mocap) onto **demovps**
(`dev.taila8bdbd.ts.net`) as a fully isolated demo instance.

Isolated means isolated: the deployed copy has no network path back to
production `signcollect.nl`, by URL rewrite *and* by firewall. See the spec
in `docs/superpowers/specs/`.

- `scripts/` - clone, rewrite, deploy, verify
- `db/`      - schema-only dump (no data)
- `docs/`    - design spec
