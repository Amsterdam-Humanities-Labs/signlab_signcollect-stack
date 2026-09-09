# Documentation

- **[machines.md](machines.md)** — the estate indexed by machine rather than by
  repository: for each host, what runs on it and the systemd unit, timer or
  cron entry it runs as. What an outage runbook needs to name things.
- **[install.md](install.md)** — standing a host up from nothing: what the
  host needs first, the one command in both modes, every flag, what preflight
  checks, what the eleven steps do, and how to verify the result.
- **[deploy.md](deploy.md)** — how the deploy actually works: the git-only
  model, what happens per component on the host, redeploying, and how to add a
  component repository.

The [operations manual](../MANUAL.md) is the other half: not how to install
the estate, but how to *use* it, one repository at a time, with live links.
