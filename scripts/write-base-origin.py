#!/usr/bin/env python3
"""Print the origin of the band write base (scheme://host).

Used by pages-deploy.yml so live smoke tracks the URL written onto bands.
The source is contracts/d-codec-fixtures.json, shared with the iOS repo.
Fails closed if that file cannot be parsed.
"""
from __future__ import annotations

import json
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "contracts" / "d-codec-fixtures.json"


def write_base_url(payload: dict) -> str:
    url = payload.get("writeBase")
    if not isinstance(url, str) or not url:
        raise SystemExit("contracts/d-codec-fixtures.json writeBase missing")
    parsed = urlparse(url)
    if parsed.scheme not in ("https", "http") or not parsed.netloc:
        raise SystemExit(f"write base is not an http(s) URL: {url!r}")
    return f"{parsed.scheme}://{parsed.netloc}"


def main() -> int:
    payload = json.loads(FIXTURES.read_text(encoding="utf-8"))
    print(write_base_url(payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
