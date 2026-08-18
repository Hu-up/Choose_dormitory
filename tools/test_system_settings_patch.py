from __future__ import annotations

import json
import urllib.error
import urllib.request


SUPABASE_URL = "https://kzyxwnvjhojzayregxgc.supabase.co"
SUPABASE_ANON_KEY = "sb_publishable_SEzzFIpvvqv8fLvtphWfdA_8pnzVdQM"


def main() -> None:
    data = json.dumps(
        {
            "is_open": True,
            "opens_at": None,
            "closes_at": None,
        },
        ensure_ascii=False,
    ).encode("utf-8")

    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/system_settings?id=eq.main",
        data=data,
        method="PATCH",
        headers={
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
            "Accept": "application/json",
            "Content-Type": "application/json; charset=utf-8",
            "Prefer": "return=representation",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            print("STATUS", response.status)
            print(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        print("ERROR", error.code)
        print(error.read().decode("utf-8", errors="replace"))


if __name__ == "__main__":
    main()
