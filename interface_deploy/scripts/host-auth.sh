#!/usr/bin/env bash
# Give a demo host read access to the private GitHub repos, using YOUR gh login.
#
# The deploy no longer rsyncs a built tree up - the host clones from GitHub
# itself - so every host needs credentials for ~17 private repos. This
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
# WITH --local THERE IS NO SECOND ACCOUNT TO COPY FROM
#
# "take the workstation's token and give it to the host" has no meaning when
# the workstation IS the host - it would be handing gh its own token back. So
# in local mode this installs gh and then stops, because the one thing it
# cannot do for you is log a machine in to GitHub as you. It says exactly
# that, rather than failing later inside a clone with "repository not found",
# which is what a private repo looks like to an unauthenticated client.
#
# The workstation-side checks moved below the install for the same reason:
# they only apply to the ssh path, and on a bare host in local mode the old
# order died with "gh is not installed on this workstation" before the step
# that installs gh had run.
#
# Usage: scripts/host-auth.sh --host gomer@dev2
set -euo pipefail

cd "$(dirname "$0")/.."
SC_USAGE='usage: scripts/host-auth.sh [--host <ssh-target> | --local]'
# shellcheck source=scripts/_common.sh
. scripts/_common.sh
sc_parse_common "$@"
sc_require_host
sc_on_error "scripts/host-auth.sh $(sc_retry_args)"

# --- 1. gh on the host ---------------------------------------------------
# From GitHub's own apt repo; Ubuntu's archive does not carry gh.
sc_doing "installing gh on the host" \
  "The host needs gh for the private org repos. If apt failed, check the host has outbound HTTPS."
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
    # dpkg ignores -qq; see provision.sh for why its output goes to a log.
    log=/tmp/signcollect-apt.log
    if ! { sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq &&
           sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gh; } >"$log" 2>&1; then
      tail -25 "$log" >&2
      exit 1
    fi
    echo "  gh installed ($(gh --version | head -1))"
  fi'

# --- 2. authenticate, unless it already can ------------------------------
sc_doing "authenticating the host to GitHub"
if ssh "$HOST" 'gh auth status >/dev/null 2>&1'; then
  echo "  host gh already authenticated as $(ssh "$HOST" 'gh api user -q .login 2>/dev/null')"
elif [ "${SC_LOCAL:-0}" = "1" ] && [ -t 0 ] && [ -t 1 ]; then
  # Someone is at this terminal, so ask them now rather than stopping and
  # telling them to type the same command and start over. --web is the device
  # flow: gh prints a one-time code and opens the browser where it can, and
  # the code works from any other machine's browser where it cannot.
  echo "  this machine has no GitHub login yet - logging in now (once)"
  echo "  gh will show a one-time code; enter it at https://github.com/login/device"
  gh auth login --hostname github.com --git-protocol https --web ||
    sc_fail "GitHub login did not complete" \
"Try it again on its own, then re-run the install:

    gh auth login
    scripts/install.sh $(sc_retry_args)"
  echo "  logged in as $(gh api user -q .login 2>/dev/null)"
elif [ "${SC_LOCAL:-0}" = "1" ]; then
  # No terminal to ask on (piped, or run from a script): the one thing this
  # script cannot do for you.
  sc_fail "this host has no GitHub login, and --local has no other machine to take one from" \
"Over ssh the host is handed a token from the workstation's gh. Running on the
host itself there is no workstation, so log in here, once:

    gh auth login

Choose GitHub.com, HTTPS, and authenticate with a browser or a token that can
read Amsterdam-Humanities-Labs. Then re-run:

    scripts/install.sh $(sc_retry_args)"
else
  command -v gh >/dev/null 2>&1 || sc_fail "gh is not installed on this workstation" \
"It is the source of the token the host is given.

    brew install gh && gh auth login       (macOS)
    sudo apt install gh && gh auth login   (Debian/Ubuntu)

Or run the installer on the demo host itself, where it needs no workstation:
    scripts/install.sh --local $([ "${WEBROOT:-/web}" = /web ] || echo "--webroot $WEBROOT")"
  gh auth token >/dev/null 2>&1 || sc_fail "this workstation's gh is not logged in" \
"The host is authorised with a token taken from your gh login.

    gh auth login"
  # --with-token reads stdin. Nothing is echoed and nothing lands in argv.
  gh auth token | ssh "$HOST" 'gh auth login --with-token'
  echo "  host gh authenticated as $(ssh "$HOST" 'gh api user -q .login 2>/dev/null') (token not shown)"
fi

# --- 3. let git use it ---------------------------------------------------
# Without this, `git clone https://github.com/...` still prompts for a
# username; gh only wires itself in as a credential helper when asked.
sc_doing "wiring gh in as git's credential helper"
ssh "$HOST" 'gh auth setup-git && echo "  git credential helper configured"'

# --- 4. prove it, rather than assume -------------------------------------
sc_doing "proving the host can read a private org repo"
ssh "$HOST" 'git ls-remote https://github.com/Amsterdam-Humanities-Labs/signlab_zin >/dev/null 2>&1' ||
  sc_fail "the host still cannot read the private org repos" \
"gh reports a login but git cannot fetch Amsterdam-Humanities-Labs/signlab_zin.
Usually the account is not a member of that organisation, or the token lacks
the 'repo' scope.

Check, on the host:
    gh auth status
    git ls-remote https://github.com/Amsterdam-Humanities-Labs/signlab_zin"
echo "  verified: host can read a private org repo"
