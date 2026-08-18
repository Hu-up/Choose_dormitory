from __future__ import annotations

import json
import urllib.error
import urllib.request


SUPABASE_URL = "https://kzyxwnvjhojzayregxgc.supabase.co"
SUPABASE_ANON_KEY = "sb_publishable_SEzzFIpvvqv8fLvtphWfdA_8pnzVdQM"


def get(path: str):
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/{path}",
        headers={
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
            "Accept": "application/json",
            "Prefer": "count=exact",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            text = response.read().decode("utf-8")
            return {
                "status": response.status,
                "content_range": response.headers.get("Content-Range"),
                "sample": json.loads(text) if text else None,
            }
    except urllib.error.HTTPError as error:
        return {
            "status": error.code,
            "error": error.read().decode("utf-8", errors="replace"),
        }


def post_rpc(function_name: str, body: dict):
    data = json.dumps(body, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/rpc/{function_name}",
        data=data,
        method="POST",
        headers={
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
            "Accept": "application/json",
            "Content-Type": "application/json; charset=utf-8",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            text = response.read().decode("utf-8")
            return {
                "status": response.status,
                "body": json.loads(text) if text else None,
            }
    except urllib.error.HTTPError as error:
        return {
            "status": error.code,
            "error": error.read().decode("utf-8", errors="replace"),
        }


def main() -> None:
    checks = {
        "dorms": get("dorms?select=id,name,gender,capacity&limit=3"),
        "records": get("records?select=id,student_id,dorm_id&limit=3"),
        "allowed_students": get("allowed_students?select=student_id,name,gender&limit=3"),
        "system_settings": get("system_settings?select=*&id=eq.main"),
        "audit_log": get("audit_log?select=id,created_at,action&limit=3"),
        "choose_dorm_rpc": post_rpc(
            "choose_dorm",
            {
                "p_name": "数据库检查",
                "p_gender": "男",
                "p_student_id": "120242227000",
                "p_dorm_id": "__check_only__",
            },
        ),
    }
    print(json.dumps(checks, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
