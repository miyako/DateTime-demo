#!/usr/bin/env python3
"""Download the DateTime component release declared in dependencies.json.

This is the headless stand-in for 4D's Dependency Manager: tool4d cannot fetch
GitHub dependencies itself, so the component is unpacked into Components/ (the
folder 4D and tool4d load components from) before a headless run.

Usage:
    python3 scripts/fetch_dependency.py [--tag 0.1.3] [--destination Components]
"""
import argparse
import json
import os
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path

API = "https://api.github.com/repos/miyako/DateTime/releases/tags/{tag}"
ASSET = "DateTime.zip"


def _request(url):
    headers = {"User-Agent": "DateTime-demo-fetch", "Accept": "application/vnd.github+json"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = "Bearer " + token
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as response:
        return response.read()


def _safe_extract(archive, destination):
    destination = destination.resolve()
    for member in archive.infolist():
        target = (destination / member.filename).resolve()
        if target != destination and destination not in target.parents:
            raise ValueError("unsafe archive member: " + member.filename)
        if member.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        with archive.open(member) as source, open(target, "wb") as output:
            shutil.copyfileobj(source, output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag")
    parser.add_argument("--destination", type=Path, default=Path("Components"))
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    declaration = json.loads((root / "Project/Sources/dependencies.json").read_text())
    entry = declaration["dependencies"]["DateTime"]
    tag = args.tag or entry.get("tag") or "0.1.3"

    target = args.destination / "DateTime.4dbase"
    if (target / "DateTime.4DZ").is_file():
        print(f"component already staged at {target}")
        return 0

    release = json.loads(_request(API.format(tag=tag)))
    asset = next((item for item in release.get("assets", []) if item["name"] == ASSET), None)
    if asset is None:
        print(f"release {tag} has no {ASSET} asset", file=sys.stderr)
        return 1

    print(f"downloading {asset['name']} from release {tag}")
    payload = _request(asset["browser_download_url"])
    archive_path = root / "Components" / (ASSET + ".download")
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    archive_path.write_bytes(payload)
    try:
        with zipfile.ZipFile(archive_path) as archive:
            _safe_extract(archive, args.destination)
    finally:
        archive_path.unlink(missing_ok=True)

    if not (target / "DateTime.4DZ").is_file():
        print(f"unpacked release does not contain {target / 'DateTime.4DZ'}", file=sys.stderr)
        return 1
    print(f"staged {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
