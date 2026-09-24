#!/usr/bin/env python3
"""Archive the public signlab_* repos on Figshare, one software item per repo.

For every public repo in the org (minus EXCLUDE) it:
  1. zips the default branch (git archive, no .git),
  2. finds or creates a Figshare item "<repo> (source code)", type software,
     license CC BY 4.0, and uploads the zip (replacing an older one),
  3. reserves a DOI for the item,
  4. adds it to the collection COLLECTION (created if missing) and reserves
     the collection's DOI.
Nothing is published on Figshare unless --publish is given: items stay drafts
with a reserved DOI, so the metadata can be checked first.

Only public repos are picked up: make a repo public on GitHub first (after the
secret scan), then run this. Same API calls and retry rules as
figshareZNN/upload_api.py on the server.

    FIGSHARE_TOKEN=... scripts/figshare-repos.py            # dry run: the plan only
    FIGSHARE_TOKEN=... scripts/figshare-repos.py --apply    # upload, reserve DOIs
    FIGSHARE_TOKEN=... scripts/figshare-repos.py --apply --publish

State (repo -> item id, DOI, archived commit) is kept in figshare-repos.json
next to this script, so a re-run only uploads repos whose branch moved.
"""
import argparse, hashlib, json, os, subprocess, sys, tempfile, time
import requests

ORG = "Amsterdam-Humanities-Labs"
PREFIX = "signlab_"
# Not software, or not ours to redistribute: videos of participants, Sony's SDK.
EXCLUDE = {"signlab_demo-media", "signlab_Sony-SDK-MACOS-API"}
BASE = "https://api.figshare.com/v2"
COLLECTION = "SignCollect: source code"
COLLECTION_DESC = ("Source code of SignCollect, the Signlab (UvA/AUAS) platform for recording, "
                   "annotating and publishing sign language data (Zin in NGT, BAK, 3DLEX), "
                   "one item per GitHub repository.")
LICENSE_NAME = "CC BY 4.0"
CATEGORY_ID = 58319  # Language, Communication and Culture, as in figshareZNN
TAGS = ["sign language", "NGT", "SignCollect", "Signlab", "source code"]
STATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "figshare-repos.json")


def req(method, path, **kw):
    """Figshare call with backoff on 403/429/5xx (403 is Figshare's burst limit)."""
    url = path if path.startswith("http") else BASE + path
    headers = {"Authorization": f"token {os.environ['FIGSHARE_TOKEN']}"} if url.startswith(BASE) else {}
    last = None
    for attempt in range(10):
        try:
            r = requests.request(method, url, headers=headers, timeout=600, **kw)
        except requests.RequestException as e:
            last = e; time.sleep(min(60, 2 ** attempt)); continue
        if r.status_code in (403, 429) or r.status_code >= 500:
            last = f"{r.status_code} {r.text[:100]}"; time.sleep(min(60, 2 ** attempt)); continue
        r.raise_for_status()
        try:
            return r.json()
        except ValueError:  # part PUTs and some POSTs answer with an empty or plain body
            return {}
    raise RuntimeError(f"{method} {url}: {last}")


def pages(path):
    out, page = [], 1
    while True:
        batch = req("GET", path, params={"page": page, "page_size": 100})
        if not batch:
            return out
        out += batch; page += 1


def entity_id(resp):
    return resp.get("entity_id") or int(resp["location"].rstrip("/").split("/")[-1])


def public_repos():
    out = subprocess.run(["gh", "repo", "list", ORG, "--visibility", "public", "--limit", "500",
                          "--json", "name,description,defaultBranchRef,url"],
                         check=True, capture_output=True, text=True).stdout
    return sorted((r for r in json.loads(out)
                   if r["name"].startswith(PREFIX) and r["name"] not in EXCLUDE),
                  key=lambda r: r["name"])


def archive(repo, workdir):
    """Shallow clone of the default branch -> (zip path, commit sha)."""
    src = os.path.join(workdir, repo["name"])
    branch = repo["defaultBranchRef"]["name"]
    subprocess.run(["git", "clone", "-q", "--depth", "1", "--branch", branch, repo["url"] + ".git", src], check=True)
    sha = subprocess.run(["git", "-C", src, "rev-parse", "HEAD"], check=True, capture_output=True, text=True).stdout.strip()
    zip_path = os.path.join(workdir, f"{repo['name']}-{sha[:7]}.zip")
    subprocess.run(["git", "-C", src, "archive", "--format=zip", f"--prefix={repo['name']}/", "-o", zip_path, "HEAD"], check=True)
    return zip_path, sha


def upload(article_id, path):
    """initiate -> parts -> complete, as upload_api.upload_one_file."""
    h, size = hashlib.md5(), 0
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk); size += len(chunk)
    file_url = req("POST", f"/account/articles/{article_id}/files",
                   json={"name": os.path.basename(path), "md5": h.hexdigest(), "size": size})["location"]
    upload_url = req("GET", file_url)["upload_url"]
    with open(path, "rb") as f:
        for p in req("GET", upload_url)["parts"]:
            f.seek(p["startOffset"])
            req("PUT", f"{upload_url}/{p['partNo']}", data=f.read(p["endOffset"] - p["startOffset"] + 1))
    req("POST", file_url)


def metadata(repo, sha, license_id):
    url = repo["url"]
    return {
        "title": f"{repo['name']} (source code)",
        "description": (f"<p>{repo['description'] or repo['name']}</p>"
                        f"<p>Snapshot of <a href=\"{url}\">{url}</a> at commit "
                        f"<code>{sha}</code>. Part of SignCollect, Signlab (UvA/AUAS).</p>"),
        "defined_type": "software",
        "license": license_id,
        "categories": [CATEGORY_ID],
        "tags": TAGS,
        "references": [url],
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--apply", action="store_true", help="upload and reserve DOIs (default: plan only)")
    ap.add_argument("--publish", action="store_true", help="also publish the items and the collection")
    ap.add_argument("repos", nargs="*", help="limit to these repo names")
    args = ap.parse_args()
    if args.publish and not args.apply:
        ap.error("--publish needs --apply")
    if "FIGSHARE_TOKEN" not in os.environ:
        ap.error("set FIGSHARE_TOKEN")

    state = json.load(open(STATE)) if os.path.exists(STATE) else {}
    licenses = {l["name"]: l["value"] for l in req("GET", "/account/licenses")}
    if LICENSE_NAME not in licenses:
        sys.exit(f"license {LICENSE_NAME!r} not offered; have: {', '.join(licenses)}")
    items = {a["title"]: a["id"] for a in pages("/account/articles")}
    repos = [r for r in public_repos() if not args.repos or r["name"] in args.repos]
    print(f"{len(repos)} public repos, license {LICENSE_NAME} (id {licenses[LICENSE_NAME]})")

    with tempfile.TemporaryDirectory() as tmp:
        for repo in repos:
            name = repo["name"]
            zip_path, sha = archive(repo, tmp)
            meta = metadata(repo, sha, licenses[LICENSE_NAME])
            aid = state.get(name, {}).get("id") or items.get(meta["title"])
            if state.get(name, {}).get("sha") == sha:
                print(f"  {name}: up to date ({state[name].get('doi')})"); continue
            print(f"  {name}: {'update item ' + str(aid) if aid else 'new item'}, "
                  f"{os.path.getsize(zip_path) // 1024} KB at {sha[:7]}")
            if not args.apply:
                continue
            if aid:
                req("PUT", f"/account/articles/{aid}", json=meta)
                for f in req("GET", f"/account/articles/{aid}/files"):
                    req("DELETE", f"/account/articles/{aid}/files/{f['id']}")
            else:
                aid = entity_id(req("POST", "/account/articles", json=meta))
            upload(aid, zip_path)
            doi = req("GET", f"/account/articles/{aid}").get("doi") or \
                  req("POST", f"/account/articles/{aid}/reserve_doi")["doi"]
            state[name] = {"id": aid, "doi": doi, "sha": sha}
            json.dump(state, open(STATE, "w"), indent=1, sort_keys=True)
            print(f"    item {aid}, DOI {doi}")

    if not args.apply:
        print(f"dry run: nothing uploaded. Collection {COLLECTION!r} would get these items.")
        return
    cols = [c for c in pages("/account/collections") if c["title"] == COLLECTION]
    cid = cols[0]["id"] if cols else entity_id(req("POST", "/account/collections", json={
        "title": COLLECTION, "description": COLLECTION_DESC,
        "categories": [CATEGORY_ID], "tags": TAGS}))
    have = {a["id"] for a in pages(f"/account/collections/{cid}/articles")}
    new = [s["id"] for s in state.values() if s["id"] not in have]
    for i in range(0, len(new), 10):  # the API takes at most 10 ids per call
        req("POST", f"/account/collections/{cid}/articles", json={"articles": new[i:i + 10]})
    cdoi = req("GET", f"/account/collections/{cid}").get("doi") or \
           req("POST", f"/account/collections/{cid}/reserve_doi")["doi"]
    print(f"collection {cid} ({COLLECTION}): +{len(new)} items, DOI {cdoi}")

    if args.publish:
        for name, s in sorted(state.items()):
            req("POST", f"/account/articles/{s['id']}/publish"); print(f"  published {name}")
        req("POST", f"/account/collections/{cid}/publish"); print("  published collection")


if __name__ == "__main__":
    main()
