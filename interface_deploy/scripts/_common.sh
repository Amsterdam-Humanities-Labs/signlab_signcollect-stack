#!/usr/bin/env bash
# Shared argument handling. Sourced, never executed.
#
# Every script here needs the same two facts - which host, and which name it
# is served as - and until now each carried its own default for them. Those
# defaults named one particular machine (demovps, dev.taila8bdbd.ts.net) and
# that machine has been decommissioned, so a bare `scripts/verify.sh` spent
# its time SSHing at something that no longer exists and then reported the
# timeout as a failure of the demo.
#
# A default that names a machine is worse than no default at all. HOST is the
# obvious case - it either times out or, worse, reaches a host you did not
# mean. DOMAIN is the quiet one: it is substituted into cookie domains and
# into the redirect allow-lists in login.html / logout.html, so a stale value
# deploys cleanly, serves pages, and silently refuses to sign anyone in.
#
# So: no defaults. Ask, or derive from the host itself.
#
#   --host <ssh-target>   or HOST=...    required by everything
#   --domain <name>       or DOMAIN=...  optional; derived from the host
#   --webroot <path>      or WEBROOT=...  optional; where the site is installed
#   --local                              run on this machine, no ssh at all
#
# DOMAIN is derived from `tailscale status --self` because that is the only
# name the TLS certificate can have: `tailscale cert` issues for a node's own
# MagicDNS name and nothing else, so any other answer would produce a cert
# the browser rejects. Asking the host removes the parameter and the entire
# class of mistake at once. --domain remains for hosts with no tailscale,
# where you supply the certificate yourself.

# Collected non-option arguments, for callers that take their own.
sc_args=()

# SC_USAGE is set by the caller before sourcing or before the first call.
sc_die() { printf '%s\n' "$*" >&2; [ -n "${SC_USAGE:-}" ] && printf '\n%s\n' "$SC_USAGE" >&2; exit 2; }

sc_parse_common() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)   printf '%s\n' "${SC_USAGE:-no usage available}"; exit 0 ;;
      --host)      [ $# -ge 2 ] || sc_die "--host needs a value";   HOST=$2;   shift 2 ;;
      --host=*)    HOST=${1#--host=};     shift ;;
      --domain)    [ $# -ge 2 ] || sc_die "--domain needs a value"; DOMAIN=$2; shift 2 ;;
      --domain=*)  DOMAIN=${1#--domain=}; shift ;;
      --webroot)   [ $# -ge 2 ] || sc_die "--webroot needs a value"; WEBROOT=$2; shift 2 ;;
      --webroot=*) WEBROOT=${1#--webroot=}; shift ;;
      --local)     SC_LOCAL=1; HOST=${HOST:-localhost}; shift ;;
      --)          shift; while [ $# -gt 0 ]; do sc_args+=("$1"); shift; done ;;
      *)           sc_args+=("$1"); shift ;;
    esac
  done
}

sc_require_host() {
  [ -n "${HOST:-}" ] || sc_die "no host given: pass --host <ssh-target> (or set HOST)"

  # One value, normalised once. A trailing slash here would produce paths like
  # /srv/signcollect//uploads, which work but read badly in every log line, and
  # SC_WEB_ROOT is compared as a string by tests/path-test.sh.
  WEBROOT=${WEBROOT:-/web}
  case "$WEBROOT" in
    /*) ;;
    *)  sc_die "--webroot must be an absolute path, got: $WEBROOT" ;;
  esac
  WEBROOT=${WEBROOT%/}
  [ -n "$WEBROOT" ] || sc_die "--webroot cannot be /"
  export WEBROOT SC_LOCAL
}

# Ask the host what it is called. Only run when the caller did not say.
sc_resolve_domain() {
  [ -z "${DOMAIN:-}" ] || return 0
  sc_require_host
  DOMAIN=$(ssh "$HOST" 'tailscale status --self --json 2>/dev/null |
      sed -n "s/.*\"DNSName\": *\"\([^\"]*\)\".*/\1/p" | head -1' 2>/dev/null | sed 's/\.$//')
  [ -n "$DOMAIN" ] || sc_die \
"could not derive the domain from $HOST (no tailscale, or not logged in).
Pass it explicitly: --domain <name-the-demo-is-served-as>
It must match the TLS certificate you install at /etc/ssl/demo/<name>.{crt,key}."
  export DOMAIN
}

# The demo hosts sit on a tailnet that has dropped out mid-deploy. Without a
# timeout ssh waits out the kernel's TCP retries - minutes - and a deploy
# that has lost its host looks like a deploy that is still working. These
# wrappers are defined for every script that sources this file, so no call
# site has to remember. ServerAlive rather than a hard timeout, because the
# long steps here (cloning 291MB of demo media) are legitimately slow while
# the connection is up.
# Every step talks to the host through these two functions and nothing else,
# which is what makes running the installer ON the host a change in one place
# rather than in fifty. With --local they execute here instead of dialling out;
# the callers are identical either way.
#
# ssh is always called as `ssh <host> <one command string>`, and scp as
# `scp [-q] <src> <host>:<dst>`, so local mode can strip the host and run the
# command, or copy the file, without parsing anything cleverer than that.
if [ "${SC_LOCAL:-0}" = "1" ]; then
  ssh() { shift; [ $# -gt 0 ] || return 0; bash -c "$*"; }
  scp() {
    local args=() a
    for a in "$@"; do case "$a" in -*) ;; *) args+=("${a#*:}") ;; esac; done
    [ ${#args[@]} -ge 2 ] || return 0
    cp "${args[@]}"
  }
else
  ssh() { command ssh -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 "$@"; }
  scp() { command scp -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 "$@"; }
fi

# Where this repo's tree lives on the host, as an unexpanded string so the
# remote shell resolves $HOME. scripts/host-src.sh puts it there.
SRCROOT=${SRCROOT:-'$HOME/signcollect-deploy'}
SRCDIR="$SRCROOT/interface_deploy"
