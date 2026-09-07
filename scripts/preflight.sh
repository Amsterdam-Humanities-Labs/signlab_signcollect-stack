#!/usr/bin/env bash
# Check everything the install needs BEFORE it changes anything.
#
# WHY THIS IS A SEPARATE STEP
#
# A run on a fresh host used to fail one step at a time: apt worked, then the
# clone failed on credentials; you fixed that, then the cert failed on
# tailscale; you fixed that, then apache would not bind because something else
# had port 443. Each attempt left the host a little further along and a little
# harder to reason about, and each error was the raw complaint of whichever
# tool gave up rather than a statement of what was wrong.
#
# Everything checked here is a precondition, not a symptom: it is knowable
# before the first package is installed, and every one of them has cost a real
# run. They are all read-only - this script installs nothing, writes nothing
# and starts nothing, so it is also the safe thing to run against a host you
# are not sure about.
#
# Usage: scripts/preflight.sh --host gomer@demo1
#        scripts/preflight.sh --local --webroot /srv/signcollect/web
set -uo pipefail

cd "$(dirname "$0")/.."
SC_USAGE='usage: scripts/preflight.sh [--host <ssh-target> | --local] [--domain <name>] [--webroot <path>]

Reports on the host every check the install depends on, and changes nothing.'
# shellcheck source=scripts/_common.sh
. scripts/_common.sh
sc_parse_common "$@"
sc_require_host

fails=0; warns=0
ok()   { printf '  ok    %-22s %s\n' "$1" "${2:-}"; }
warn() { printf '  warn  %-22s %s\n' "$1" "${2:-}"; warns=$((warns+1)); }
bad()  { printf '  FAIL  %-22s %s\n' "$1" "${2:-}"; shift 2
         [ $# -gt 0 ] && printf '%s\n' "$@" | sed 's/^/          /'
         fails=$((fails+1)); return 0; }

echo "== preflight: $(sc_where), webroot $WEBROOT =="

# --- 1. this machine ------------------------------------------------------
# Over ssh the workstation is part of the deploy: it holds the gh token the
# host is given, and `git archive` is how the working tree reaches the host.
# With --local none of that applies, because there is no workstation.
if [ "${SC_LOCAL:-0}" = "1" ]; then
  ok "mode" "--local: this machine is the demo host, no ssh"
  case "$(uname -s)" in
    Linux) ok "this machine" "Linux" ;;
    *) bad "this machine" "$(uname -s), not Linux" \
         "--local means 'I am the demo host'. The demo host is an Ubuntu box." \
         "From a Mac or elsewhere, deploy over ssh instead:" \
         "  scripts/install.sh --host <user>@<host>" ;;
  esac
else
  ok "mode" "over ssh to $HOST"
  for t in ssh git tar gzip curl; do
    command -v "$t" >/dev/null 2>&1 || bad "workstation $t" "not installed" \
      "install $t on this machine, or run the installer on the host with --local"
  done
  if command -v gh >/dev/null 2>&1; then
    if gh auth token >/dev/null 2>&1; then
      ok "workstation gh" "logged in as $(gh api user -q .login 2>/dev/null || echo '?')"
    else
      bad "workstation gh" "installed but not logged in" \
        "The host is given a token taken from this machine's gh login." \
        "Fix:  gh auth login"
    fi
  else
    bad "workstation gh" "not installed" \
      "The host clones ~17 private repositories and is authorised with a token" \
      "from your gh login, so this machine needs one." \
      "Fix:  brew install gh && gh auth login     (or apt install gh)"
  fi
  if [ -d .git ] && git rev-parse HEAD >/dev/null 2>&1; then
    ok "deploy tree" "$(git rev-parse --short HEAD) overlays onto the host"
  else
    warn "deploy tree" "not a git checkout - the host will run the mirrored tree only"
  fi
fi

# --- 2. can we talk to the host at all ------------------------------------
# First, and on its own, because every check after this is a question asked of
# the host: if this fails, the rest would fail as a cascade of timeouts that
# say nothing about the host.
if [ "${SC_LOCAL:-0}" != "1" ]; then
  reachable=no
  err=$(command ssh -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new \
        "$HOST" 'echo reachable' 2>&1)
  case "$err" in
    *reachable*) ok "ssh $HOST" "reachable"; reachable=yes ;;
    *"Permission denied"*|*"publickey"*)
      bad "ssh $HOST" "refused the key" \
        "The host is up but will not let this key in." \
        "Fix:  ssh-copy-id $HOST        (then re-run)" ;;
    *"Could not resolve"*|*"Name or service not known"*|*"nodename nor servname"*)
      bad "ssh $HOST" "no such name" \
        "Nothing answers to that name. A tailnet host needs tailscale up here too." \
        "Check:  tailscale status | grep ${HOST#*@}" ;;
    *"Connection refused"*)
      bad "ssh $HOST" "connection refused" "Nothing is listening on port 22 there. Is the machine booted?" ;;
    *"timed out"*|*"Operation timed out"*|*"Connection timed out"*)
      bad "ssh $HOST" "timed out after 12s" \
        "The name resolves but nothing answers. These demo hosts are OrbStack" \
        "machines on a laptop and go away when it sleeps." ;;
    *) bad "ssh $HOST" "failed" "$err" ;;
  esac
  # Only the ssh check gates the rest. A workstation-side failure (no gh, say)
  # is worth knowing about alongside everything the host has to say, so it is
  # reported and the run continues; an unreachable host makes every later check
  # a timeout that describes the link rather than the host.
  if [ "$reachable" != "yes" ]; then
    echo
    echo "  preflight stopped: the host is not reachable, so nothing else could be checked."
    exit 1
  fi
fi

# --- 3. everything the host must be able to do ----------------------------
# One round trip, not fifteen: the tailnet these hosts sit on has dropped out
# mid-deploy, and a preflight that needs the link up fifteen separate times is
# its own source of flakiness. The block prints key:value lines and this side
# reads them, so adding a check is one line at each end.
probe=$(ssh "$HOST" '
  set +e
  . /etc/os-release 2>/dev/null
  echo "os:${PRETTY_NAME:-unknown}"
  echo "user:$(id -un)"
  command -v apt-get >/dev/null && echo "apt:yes" || echo "apt:no"
  sudo -n true 2>/dev/null && echo "sudo:yes" || echo "sudo:no"
  command -v systemctl >/dev/null && echo "systemd:yes" || echo "systemd:no"
  command -v python3   >/dev/null && echo "python3:yes" || echo "python3:no"
  command -v curl      >/dev/null && echo "curl:yes" || echo "curl:no"
  command -v git       >/dev/null && echo "git:yes" || echo "git:no"
  if command -v gh >/dev/null; then
    gh auth status >/dev/null 2>&1 && echo "gh:$(gh api user -q .login 2>/dev/null || echo yes)" || echo "gh:unauthed"
  else echo "gh:absent"; fi
  if command -v tailscale >/dev/null; then
    n=$(tailscale status --self --json 2>/dev/null | sed -n "s/.*\"DNSName\": *\"\([^\"]*\)\".*/\1/p" | head -1)
    echo "ts:${n%.}"
  else echo "ts:absent"; fi
  # Free space where the site will live: the nearest ancestor that exists.
  p="'"$WEBROOT"'"; while [ ! -d "$p" ] && [ "$p" != "/" ]; do p=$(dirname "$p"); done
  echo "diskpath:$p"
  echo "diskkb:$(df -Pk "$p" | awk "NR==2{print \$4}")"
  echo "webroot:$([ -d "'"$WEBROOT"'" ] && echo present || echo absent)"
  echo "memkb:$(awk "/MemTotal/{print \$2}" /proc/meminfo 2>/dev/null)"
  if command -v ss >/dev/null; then
    for p in 80 443; do
      ss -ltnH 2>/dev/null | awk "{print \$4}" | grep -qE "[:.]$p\$" && echo "port$p:busy" || echo "port$p:free"
    done
  else echo "port80:unknown"; echo "port443:unknown"; fi
  systemctl is-active apache2 >/dev/null 2>&1 && echo "apache:active" || echo "apache:no"
  code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 25 https://github.com 2>/dev/null)
  echo "github:${code:-fail}"
' 2>/dev/null)
g() { printf '%s\n' "$probe" | sed -n "s/^$1://p" | head -1; }

[ -n "$probe" ] || { bad "host probe" "returned nothing" "The host answered ssh and then gave no output - check it by hand:" "  ssh $HOST true"; echo; exit 1; }

ok   "host" "$(g os) as $(g user)"

case "$(g sudo)" in
  yes) ok "passwordless sudo" "$(g user) can sudo without a password" ;;
  *)   bad "passwordless sudo" "sudo -n failed for $(g user)" \
         "Everything privileged here runs non-interactively, so a sudo that asks" \
         "for a password stops the install dead half way through." \
         "Fix, as root on the host:" \
         "  echo '$(g user) ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$(g user)" \
         "  chmod 440 /etc/sudoers.d/$(g user)" ;;
esac

case "$(g apt)" in
  yes) ok "package manager" "apt-get" ;;
  *)   bad "package manager" "no apt-get" \
         "provision.sh installs apache/php/mysql with apt. This host is not Debian-family." ;;
esac

case "$(g github)" in
  200|301|302) ok "github.com" "reachable from the host (HTTP $(g github))" ;;
  *) bad "github.com" "not reachable from the host" \
       "The host clones ~17 repositories itself; without outbound HTTPS to" \
       "github.com nothing can be deployed." \
       "Check:  ssh $HOST 'curl -sSI https://github.com | head -1'" \
       "If scripts/isolate.sh over-blocked, see /etc/nftables.d/signcollect-isolation.nft" ;;
esac

# gh on the host. Over ssh this is filled in for you from the workstation's
# token; with --local there is no other machine to take one from, so it is a
# precondition rather than something the install can arrange.
case "$(g gh)" in
  absent)
    if [ "${SC_LOCAL:-0}" = "1" ]; then
      bad "host gh" "not installed, and --local has no workstation to borrow a login from" \
        "Fix, in order:" \
        "  scripts/host-auth.sh --local     # installs gh" \
        "  gh auth login                    # your own GitHub account" \
        "  scripts/install.sh $(sc_retry_args)"
    else
      ok "host gh" "absent - host-auth.sh will install it and hand it your token"
    fi ;;
  unauthed)
    if [ "${SC_LOCAL:-0}" = "1" ]; then
      bad "host gh" "installed but not logged in" \
        "With --local the host is the only machine in the picture, so it needs" \
        "its own GitHub login for the ~17 private repositories." \
        "Fix:  gh auth login"
    else
      ok "host gh" "not logged in - host-auth.sh will hand it your token"
    fi ;;
  *) ok "host gh" "logged in as $(g gh)" ;;
esac

# The domain. Derived from tailscale unless given, because `tailscale cert`
# issues for that name and no other - a name we guessed could not have a cert.
if [ -n "${DOMAIN:-}" ]; then
  ok "domain" "$DOMAIN (given)"
  [ "$(g ts)" = "absent" ] && warn "tls" "no tailscale: supply /etc/ssl/demo/$DOMAIN.{crt,key} yourself"
elif [ "$(g ts)" = "absent" ] || [ -z "$(g ts)" ]; then
  bad "domain" "no tailscale on the host and no --domain given" \
    "The demo's hostname is read off the host with 'tailscale status --self'," \
    "which is also the only name 'tailscale cert' will issue for." \
    "Either:  ssh $HOST 'sudo tailscale up'" \
    "or:      re-run with --domain <name> and put the certificate at" \
    "         /etc/ssl/demo/<name>.{crt,key} on the host"
else
  ok "domain" "$(g ts) (from the host's tailscale)"
fi

for t in git curl python3 systemd; do
  case "$(g "$t")" in
    yes) ok "host $t" "present" ;;
    *) case "$t" in
         git|curl)  ok "host $t" "absent - provision.sh installs it" ;;
         python3)   bad "host $t" "absent" "pythonCron's scheduler needs python3; Ubuntu ships it." ;;
         systemd)   bad "host $t" "absent" "The scheduler is a systemd unit; there is nowhere to install it." ;;
       esac ;;
  esac
done

# Disk. 291MB of demo media, seventeen checkouts, apt's own cache, and a
# database. Two gigabytes is tight; five is comfortable.
kb=$(g diskkb); kb=${kb:-0}
gb=$(( kb / 1048576 ))
if   [ "$kb" -lt 2097152 ]; then bad "disk space" "${gb}G free on $(g diskpath)" \
       "The demo media alone is 291MB and the checkouts and database add more." \
       "Free at least 3G, or install onto another filesystem with --webroot."
elif [ "$kb" -lt 5242880 ]; then warn "disk space" "${gb}G free on $(g diskpath) - tight but workable"
else ok "disk space" "${gb}G free on $(g diskpath)"; fi

mem=$(g memkb); mem=${mem:-0}
[ "$mem" -gt 0 ] && [ "$mem" -lt 900000 ] && warn "memory" "$((mem/1024))MB - mysql-server may fail to start below ~1G"

# Ports. apache is the intended occupant; anything else means the vhost will
# come up and serve nothing, which is a confusing way to find out.
for p in 80 443; do
  case "$(g "port$p")" in
    free) ok "port $p" "free" ;;
    busy) if [ "$(g apache)" = "active" ]; then ok "port $p" "held by apache2 (this demo, or the last one)"
          else bad "port $p" "held by something that is not apache2" \
                 "apache2 will not be able to bind it and the demo will not serve." \
                 "Look:  ssh $HOST 'sudo ss -ltnp | grep :$p'"; fi ;;
    *) warn "port $p" "could not check (no ss on the host)" ;;
  esac
done

case "$(g webroot)" in
  present) ok "webroot" "$WEBROOT exists - this is a redeploy" ;;
  *)       ok "webroot" "$WEBROOT does not exist yet - it will be created" ;;
esac

echo
if [ $fails -gt 0 ]; then
  printf '  %d check(s) failed. Nothing has been changed. Fix the above and re-run:\n' "$fails"
  printf '    scripts/install.sh %s\n\n' "$(sc_retry_args)"
  exit 1
fi
[ $warns -gt 0 ] && printf '  preflight passed with %d warning(s).\n' "$warns" || printf '  preflight passed.\n'
exit 0
