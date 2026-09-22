# README template

Every `signlab_*` repo README follows this skeleton (#18).

- Aim for 60 lines or fewer.
- Facts only. Prefer tables and bullets to prose.
- Do not repeat how deploys work, demo-host paths, credential conventions or
  the history of the organisation. Link to this repo instead
  ([install.md](install.md), [deploy.md](deploy.md), [machines.md](machines.md)).
- Put long API or vendor reference in the repo's own `docs/`.

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
