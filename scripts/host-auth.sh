#!/usr/bin/env bash
# Give a demo host read access to the private GitHub repos, using YOUR gh login.
#
# The deploy is moving from "rsync a built tree up" to "the host clones from
# GitHub itself", so every host needs credentials for ~17 private repos. This
# installs gh there and hands it a token taken from the workstation's existing
# `gh auth token` - no machine user, no per-repo deploy keys, no second account.
#
# THE TRADE, STATED PLAINLY: that token carries your full account scope,
# including write, and gh stores it on the host at ~/.config/gh/hosts.yml.
# Anyone with root on the demo box can read it and push as you. A read-only
# machine user would be the safer shape; this is the convenient one. Revoke at
# https://github.com/settings/tokens if a host is ever lost.
#
# The token is piped over stdin, never passed as an argument, so it does not
# appear in the host's process list or shell history.
#
# Idempotent: a host that can already reach GitHub is left alone.
#
# Usage: HOST=gomer@dev2 scripts/host-auth.sh
set -euo pipefail

cd "$(dirname "$0")/.."
HOST=${HOST:-demovps}

command -v gh >/dev/null 2>&1 || {
  echo "gh is not installed on this workstation - it is the source of the token" >&2
  exit 1
}
gh auth token >/dev/null 2>&1 || {
  echo "workstation gh is not logged in: run 'gh auth login' first" >&2
  exit 1
}

# --- 1. gh on the host ---------------------------------------------------
# From GitHub's own apt repo; Ubuntu's archive does not carry gh.
ssh "$HOST" 'set -e
  if command -v gh >/dev/null 2>&1; then
    echo "  gh already installed ($(gh --version | head -1))"
  else
    echo "  installing gh"
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
      sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
      sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gh
    echo "  gh installed ($(gh --version | head -1))"
  fi'

# --- 2. authenticate, unless it already can ------------------------------
if ssh "$HOST" 'gh auth status >/dev/null 2>&1'; then
  echo "  host gh already authenticated as $(ssh "$HOST" 'gh api user -q .login 2>/dev/null')"
else
  # --with-token reads stdin. Nothing is echoed and nothing lands in argv.
  gh auth token | ssh "$HOST" 'gh auth login --with-token'
  echo "  host gh authenticated as $(ssh "$HOST" 'gh api user -q .login 2>/dev/null') (token not shown)"
fi

# --- 3. let git use it ---------------------------------------------------
# Without this, `git clone https://github.com/...` still prompts for a
# username; gh only wires itself in as a credential helper when asked.
ssh "$HOST" 'gh auth setup-git && echo "  git credential helper configured"'

# --- 4. prove it, rather than assume -------------------------------------
ssh "$HOST" 'git ls-remote https://github.com/Amsterdam-Humanities-Labs/signlab_zin >/dev/null 2>&1 &&
             echo "  verified: host can read a private org repo" ||
             { echo "  FAILED: host still cannot read private repos" >&2; exit 1; }'
