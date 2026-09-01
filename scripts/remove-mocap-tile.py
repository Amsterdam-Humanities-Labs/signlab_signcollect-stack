#!/usr/bin/env python3
"""Remove the Motion Capture tile from the landing page.

Mocap is out of scope, so its tile would link nowhere. Removing the whole
<a class="tile"> block is cleaner than leaving a dead link.
"""
import re, sys

path = sys.argv[1]
html = open(path, encoding="utf-8").read()

# Match the full anchor block whose href points at the neutralised mocap target.
pattern = re.compile(
    r'\n\s*<a class="tile"[^>]*href="/mocap-removed"[^>]*>.*?</a>\n',
    re.DOTALL,
)
new, n = pattern.subn("\n", html)
if n == 0:
    print(f"no mocap tile found in {path} (already removed?)")
else:
    open(path, "w", encoding="utf-8").write(new)
    print(f"removed {n} mocap tile(s) from {path}")
