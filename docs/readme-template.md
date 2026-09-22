# README template

Every `signlab_*` repo README follows this skeleton (#18). Target: 60 lines or
fewer. Facts only; tables and bullets over prose. Do not restate the deploy
mechanism, demo-host paths, credential conventions or org history: link to
this repo ([install.md](install.md), [deploy.md](deploy.md),
[machines.md](machines.md)) instead. Long API or vendor reference goes in the
repo's own `docs/`.

```markdown
# <repo>
<one line: what it is>

## What it does
<= 6 lines

## Where it runs
<= 4 lines: machine, path, URL

## Status
1 line: production | experimental | dormant

## How to run / deploy
<= 10 lines, commands

## Configuration
<= 8 lines: files not in git, env vars

## Dependencies
<= 6 lines: other repos, services
```
