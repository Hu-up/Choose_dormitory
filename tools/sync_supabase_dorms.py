from __future__ import annotations

import json
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path


SUPABASE_URL = "https://kzyxwnvjhojzayregxgc.supabase.co"
SUPABASE_ANON_KEY = "sb_publishable_SEzzFIpvvqv8fLvtphWfdA_8pnzVdQM"


def request(method: str, path: str, body: object | None = None) -> object:
    data = None
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Accept": "application/json",
    }
    if body is not None:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json; charset=utf-8"
        headers["Prefer"] = "resolution=merge-duplicates,return=minimal"

    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/{path}",
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            text = response.read().decode("utf-8")
            return json.loads(text) if text else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{method} {path} failed: {error.code} {detail}") from error


def load_dorms(path: Path) -> list[dict]:
    content = path.read_text(encoding="utf-8")
    match = re.search(r"window\.DORM_DEFAULTS = (?P<json>.*?);\s", content, re.S)
    if not match:
        raise RuntimeError("Cannot find window.DORM_DEFAULTS in dorm-data.js")
    return json.loads(match.group("json"))


def main() -> None:
    data_file = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/dorm-data.js")
    dorms = load_dorms(data_file)

    request("POST", "dorms?on_conflict=id", dorms)
    current = request("GET", "dorms?select=id,name")

    new_ids = {dorm["id"] for dorm in dorms}
    deleted = 0
    for dorm in current:
        if dorm["id"] not in new_ids:
            encoded_id = urllib.parse.quote(dorm["id"], safe="")
            request("DELETE", f"dorms?id=eq.{encoded_id}")
            deleted += 1

    after = request("GET", "dorms?select=id,name,gender,capacity&order=name.asc")
    print(
        json.dumps(
            {
                "upserted": len(dorms),
                "deleted_old": deleted,
                "after_count": len(after),
                "has_6号楼_225": any(dorm["name"] == "6号楼-225" for dorm in after),
                "has_16号楼_8014": any(dorm["name"] == "16号楼-8014" for dorm in after),
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
