from __future__ import annotations

import json
import urllib.error
import urllib.request


SUPABASE_URL = "https://kzyxwnvjhojzayregxgc.supabase.co"
SUPABASE_ANON_KEY = "sb_publishable_SEzzFIpvvqv8fLvtphWfdA_8pnzVdQM"


def request(method: str, path: str, body: object | None = None, prefer: str | None = None):
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Accept": "application/json",
    }
    data = None
    if body is not None:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json; charset=utf-8"
    if prefer:
        headers["Prefer"] = prefer

    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/{path}",
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            text = response.read().decode("utf-8")
            return response.status, json.loads(text) if text else None
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        return error.code, detail


def main() -> None:
    results = {}
    results["before_new"] = request(
        "GET",
        "allowed_students?select=student_id,name,gender&student_id=eq.120242227157",
    )
    results["before_old_id"] = request(
        "GET",
        "allowed_students?select=student_id,name,gender&student_id=eq.120242227362",
    )

    results["upsert_sunchen"] = request(
        "POST",
        "allowed_students?on_conflict=student_id",
        [{"student_id": "120242227157", "name": "孙晨", "gender": "男"}],
        "resolution=merge-duplicates,return=representation",
    )
    results["delete_old_id"] = request(
        "DELETE",
        "allowed_students?student_id=eq.120242227362",
        prefer="return=representation",
    )
    results["delete_old_name"] = request(
        "DELETE",
        "allowed_students?name=eq.%E6%98%93%E5%98%89%E8%80%80",
        prefer="return=representation",
    )
    results["after"] = request(
        "GET",
        "allowed_students?select=student_id,name,gender&or=(student_id.eq.120242227157,student_id.eq.120242227362,name.eq.%E6%98%93%E5%98%89%E8%80%80)",
    )

    print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
