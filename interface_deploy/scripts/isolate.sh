#!/usr/bin/env bash
# Cut every network path from a demo host to production signcollect.nl.
#
# Runs ON the demo host, as that host: it edits /etc/hosts and loads an
# nftables table there. scripts/verify.sh asserts, from the outside, that it
# has been run.
#
# Two layers, because a URL rewrite is a regex and cannot be proven exhaustive:
#   1. DNS null-route in /etc/hosts
#   2. nftables reject rules on the OUTPUT hook
#
# Production is reachable BOTH publicly (136.144.170.87) and as a tailnet peer
# (cloud.taila8bdbd.ts.net, 100.88.38.8) - blocking only the public IP would
# leave the tailnet path wide open.
#
# The chain policy stays ACCEPT and only these destinations are rejected, so
# there is no way for this to cut our own SSH access.
set -euo pipefail

PUB4=136.144.170.87
TS4=100.88.38.8
TS6=fd7a:115c:a1e0::bf35:2608

# --- layer 1: DNS ---
sudo sed -i '/# signcollect-isolation/d' /etc/hosts
# Every name production answers to, not only the ones the code happens to
# mention. mocap stays on this list even though mocap is now deployed here:
# the demo serves it from /web/mocap_site under its own hostname, and the
# production subdomain must remain unreachable. avatar/signbank/api-lg are
# further vhosts on the same production host - avatar.signcollect.nl in
# particular is linked from the mocap portal.
for h in signcollect.nl api.signcollect.nl media.signcollect.nl mocap.signcollect.nl \
         avatar.signcollect.nl signbank.signcollect.nl api-lg.signcollect.nl \
         dashboard.signcollect.nl cloud.taila8bdbd.ts.net; do
  echo "127.0.0.1 $h # signcollect-isolation" | sudo tee -a /etc/hosts >/dev/null
done

# --- layer 2: packet filter ---
sudo nft delete table inet signcollect_isolation 2>/dev/null || true
sudo nft -f - <<NFT
table inet signcollect_isolation {
  chain output {
    type filter hook output priority 0; policy accept;
    ip  daddr $PUB4 counter reject with icmp type admin-prohibited
    ip  daddr $TS4  counter reject with icmp type admin-prohibited
    ip6 daddr $TS6  counter reject with icmpv6 type admin-prohibited
  }
}
NFT

# --- persist across reboot ---
sudo mkdir -p /etc/nftables.d
sudo nft list table inet signcollect_isolation | sudo tee /etc/nftables.d/signcollect-isolation.nft >/dev/null
grep -q 'nftables.d/signcollect-isolation.nft' /etc/nftables.conf 2>/dev/null || \
  echo 'include "/etc/nftables.d/signcollect-isolation.nft"' | sudo tee -a /etc/nftables.conf >/dev/null
sudo systemctl enable nftables >/dev/null 2>&1 || true
echo "isolation applied"
