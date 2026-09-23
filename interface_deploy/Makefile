# Shortcuts for the scripts in scripts/ and tests/. Nothing here that the
# scripts do not already do; see README.md for what each step means.
#
#   make install                  on the demo host itself (--local)
#   make install HOST=gomer@dev2  from a workstation, over ssh
#   make dry-run  | preflight | verify | test
#
# BASE is the demo's URL for verify/test; it defaults to the host's tailnet name.

HOST ?=
WHERE := $(if $(HOST),--host $(HOST),--local)
BASE  ?= https://$(shell $(if $(HOST),ssh $(HOST),sh -c) 'tailscale status --self --json 2>/dev/null' | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2>/dev/null)
TESTS := $(wildcard tests/*-test.sh)

.PHONY: install dry-run preflight verify test help
help:
	@sed -n '4,9p' Makefile | sed 's/^# //'

install:
	scripts/install.sh $(WHERE)

dry-run:
	scripts/install.sh $(WHERE) --dry-run

preflight:
	scripts/preflight.sh $(WHERE)

verify:
	scripts/verify.sh $(WHERE) $(BASE)

test:
	@fail=0; for t in $(TESTS); do \
	  printf '%-22s ' $$(basename $$t); \
	  HOST=$(HOST) BASE=$(BASE) bash $$t >/tmp/$$(basename $$t).log 2>&1 && tail -1 /tmp/$$(basename $$t).log || { fail=1; echo "FAILED - see /tmp/$$(basename $$t).log"; }; \
	done; exit $$fail
