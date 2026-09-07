#!/usr/bin/env bash
# Shared argument handling, and the one seam between "run it here" and "run it
# over ssh". Sourced, never executed.
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
#   --host <ssh-target>   or HOST=...     required unless --local
#   --domain <name>       or DOMAIN=...   optional; derived from the host
#   --webroot <path>      or WEBROOT=...  optional; where the site is installed
#   --local                               run on this machine, no ssh at all
#   --dry-run                             say what would change; change nothing
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
      --dry-run)   SC_DRY=1; shift ;;
      --)          shift; while [ $# -gt 0 ]; do sc_args+=("$1"); shift; done ;;
      *)           sc_args+=("$1"); shift ;;
    esac
  done
}

sc_require_host() {
  if [ "${SC_LOCAL:-0}" = "1" ]; then
    HOST=${HOST:-localhost}
  else
    [ -n "${HOST:-}" ] || sc_die \
"no host given.

Either name the machine to deploy to:
    --host <ssh-target>      e.g. --host gomer@demo1
or say that this machine IS the demo host:
    --local"
  fi

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

  # --dry-run is implemented by install.sh, which reads host state and reports
  # what it would change. No other script honours it, and a flag that is
  # silently ignored on a script that then changes the host is worse than one
  # that does not exist.
  if [ "${SC_DRY:-0}" = "1" ] && [ "${SC_DRY_OK:-0}" != "1" ]; then
    sc_die "--dry-run is implemented by scripts/install.sh only.
$(basename "${BASH_SOURCE[1]:-this script}") would have changed the host, so it refuses to pretend otherwise.
Run:  scripts/install.sh $(sc_retry_args) --dry-run"
  fi

  sc_resolve_srcdir
  export WEBROOT SC_LOCAL HOST SRCROOT SRCDIR
}

# --- where this repo's tree lives, as the host sees it ---------------------
#
# Over ssh it is a checkout scripts/host-src.sh puts at ~/signcollect-deploy,
# and the string is left unexpanded so the REMOTE shell resolves $HOME.
#
# With --local there is no second machine and no second copy: the tree we are
# running from IS the tree the host builds from. Saying so here, once, is what
# stops host-src.sh cloning a repository over the scripts that are executing
# out of it - see that file. Every script cd's to the repo root before this
# runs, so $PWD is the same answer in all of them.
sc_resolve_srcdir() {
  if [ "${SC_LOCAL:-0}" = "1" ]; then
    SRCDIR=$PWD
    SRCROOT=$(dirname "$PWD")
  else
    SRCROOT=${SRCROOT:-'$HOME/signcollect-deploy'}
    SRCDIR="$SRCROOT/interface_deploy"
  fi
}
# Placeholder values so a script that reads them before sc_require_host (or
# never calls it) still sees the remote shape rather than an unbound variable.
SRCROOT=${SRCROOT:-'$HOME/signcollect-deploy'}
SRCDIR=${SRCDIR:-"$SRCROOT/interface_deploy"}

# How to say "this host" in a message, and how to say "run that again".
sc_where() {
  if [ "${SC_LOCAL:-0}" = "1" ]; then printf 'this machine (--local)'
  else printf '%s (over ssh)' "${HOST:-?}"; fi
}
sc_retry_args() {
  local a
  if [ "${SC_LOCAL:-0}" = "1" ]; then a="--local"; else a="--host ${HOST:-<ssh-target>}"; fi
  [ "${WEBROOT:-/web}" = "/web" ] || a="$a --webroot $WEBROOT"
  printf '%s' "$a"
}

# --- failing usefully ------------------------------------------------------
#
# The failure mode this replaces is a raw diagnostic from whichever tool gave
# up - `cp: '/tmp/x' and '/tmp/x' are the same file` - printed with no
# indication of which step produced it, which machine it happened on, or what
# to type next. Every script installs this, so every failure names all three.
#
# EXIT, not ERR, and that is not a preference. bash's documented rule is that
# the ERR trap does not fire for a command inside an `if` condition or on the
# left of `||`, and this deploy is full of both - `if ssh "$HOST" 'gh auth
# status'` is how it asks a yes/no question of the host. bash 5.2 honours the
# rule; bash 3.2, which is what macOS ships and therefore what the workstation
# half of every ssh-mode deploy runs on, fires the trap anyway. The same script
# would then have printed a fabricated failure over ssh and stayed quiet with
# --local, which is precisely the shape of bug this whole exercise is about.
# EXIT fires once, on the way out, and only the real exit status reaches it.
SC_WHAT=""        # human name of the step currently running
SC_HINT=""        # what to do about it, if the step knows something specific
SC_CLEANUP=""     # anything the script must remove on the way out
SC_REPORTED=0     # sc_fail has already said its piece
sc_doing() { SC_WHAT=$1; SC_HINT=${2:-}; }
sc_on_error() {           # sc_on_error <retry command>
  SC_RETRY=$1
  trap 'sc_at_exit' EXIT
}
sc_at_exit() {
  local rc=$?
  if [ -n "${SC_CLEANUP:-}" ]; then eval "$SC_CLEANUP"; fi
  if [ "$rc" -ne 0 ] && [ "${SC_REPORTED:-0}" != "1" ]; then
    {
      printf '\n  !! FAILED  %s\n' "${SC_WHAT:-$(basename "$0")}"
      printf '     host    %s\n' "$(sc_where)"
      printf '     script  %s (exit %s)\n' "$0" "$rc"
      [ -n "${SC_HINT:-}" ] && printf '\n     %s\n' "$SC_HINT"
      printf '\n     retry just this step:\n       %s\n\n' "${SC_RETRY:-$0 $(sc_retry_args)}"
    } >&2
  fi
  exit "$rc"
}
# For a condition the script checks itself, rather than a command that failed.
sc_fail() {               # sc_fail <what> <why...>
  local what=$1; shift
  {
    printf '\n  !! %s\n' "$what"
    printf '     host    %s\n\n' "$(sc_where)"
    printf '%s\n' "$*" | sed 's/^/     /'
    printf '\n     retry:\n       %s\n\n' "${SC_RETRY:-scripts/install.sh $(sc_retry_args)}"
  } >&2
  SC_REPORTED=1
  exit 1
}

# Ask the host what it is called. Only run when the caller did not say.
sc_resolve_domain() {
  [ -z "${DOMAIN:-}" ] || { export DOMAIN; return 0; }
  sc_require_host
  DOMAIN=$(ssh "$HOST" 'tailscale status --self --json 2>/dev/null |
      sed -n "s/.*\"DNSName\": *\"\([^\"]*\)\".*/\1/p" | head -1' 2>/dev/null | sed 's/\.$//')
  [ -n "$DOMAIN" ] || sc_die \
"could not derive the domain from $(sc_where): no tailscale there, or it is not logged in.

Either log the host in:
    ssh $HOST 'sudo tailscale up'
or name the demo yourself and supply its certificate:
    --domain <name-the-demo-is-served-as>
    (the cert goes at /etc/ssl/demo/<name>.{crt,key} on the host)"
  export DOMAIN
}

# --- the seam ---------------------------------------------------------------
#
# The demo hosts sit on a tailnet that has dropped out mid-deploy. Without a
# timeout ssh waits out the kernel's TCP retries - minutes - and a deploy
# that has lost its host looks like a deploy that is still working. These
# wrappers are defined for every script that sources this file, so no call
# site has to remember. ServerAlive rather than a hard timeout, because the
# long steps here (cloning 291MB of demo media) are legitimately slow while
# the connection is up.
#
# Every step talks to the host through these functions and nothing else,
# which is what makes running the installer ON the host a change in one place
# rather than in fifty. With --local they execute here instead of dialling out;
# the callers are identical either way.
#
# ssh is always called as `ssh <host> <one command string>`, so local mode can
# strip the host and run the command without parsing anything cleverer.
# SC_LOCAL is tested inside each function, not around them: _common.sh is
# sourced before the command line is parsed, so a branch out here would be
# decided while --local is still unread - which is exactly the bug that sent
# `--local` to ssh localhost.
# SetEnv=LC_ALL: macOS sends LC_CTYPE=UTF-8, which is not a locale any Linux
# has, so every perl on the host - a2enconf, a2ensite, rewrite-urls.sh - shot
# back an eight-line "Setting locale failed" warning. Hundreds of lines of it,
# interleaved with the deploy's own output, all of it harmless and none of it
# distinguishable from a real problem by somebody deploying for the first time.
ssh() {
  if [ "${SC_LOCAL:-0}" = "1" ]; then
    shift                       # drop the host; the rest is one command string
    [ $# -gt 0 ] || return 0
    bash -c "$*"
  else
    command ssh -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 \
                -o SetEnv=LC_ALL=C.UTF-8 "$@"
  fi
}

# sc_put <path-on-host> - write stdin to that path on the host.
#
# THIS EXISTS TO DELETE A WHOLE CLASS OF BUG. The pattern it replaces was
#
#     sed template > /tmp/$out; scp /tmp/$out "$HOST:/tmp/$out"; rm -f /tmp/$out
#
# which has a workstation-side staging file, a transfer, and a cleanup - three
# steps that are only distinguishable because the two machines are different.
# Run with --local it becomes `cp /tmp/x /tmp/x` ("are the same file"), and the
# rm then deletes the file the next step reads. Adding a same-file guard would
# have patched that one line; every future "render a file onto the host" would
# have had to remember the same guard.
#
# So the staging file is gone instead of being made safe. There is one
# argument, a destination, and no source path to collide with it: over ssh the
# content goes down the pipe into `cat`, locally it goes into `cat` here.
# Nothing to clean up in either mode, because nothing extra was created.
sc_put() {
  local dest=$1
  [ -n "$dest" ] || { echo "sc_put: no destination given" >&2; return 2; }
  ssh "$HOST" "mkdir -p \"\$(dirname '$dest')\" && cat > '$dest'"
}

# Kept for any caller that genuinely has a file to move rather than content to
# write. In local mode a copy onto itself is the file already being where it
# was asked to be, which is success, not an error - so it says so and stops.
scp() {
  if [ "${SC_LOCAL:-0}" = "1" ]; then
    local args=() a
    for a in "$@"; do case "$a" in -*) ;; *) args+=("${a#"${HOST}":}") ;; esac; done
    [ ${#args[@]} -ge 2 ] || return 0
    local dst=${args[$((${#args[@]}-1))]} src
    for src in "${args[@]:0:$((${#args[@]}-1))}"; do
      if [ "$src" -ef "$dst" ] 2>/dev/null; then continue; fi
      cp "$src" "$dst"
    done
  else
    command scp -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 "$@"
  fi
}
