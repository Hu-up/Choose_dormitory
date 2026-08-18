from __future__ import annotations

import concurrent.futures
import json
import re
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from pathlib import Path


SUPABASE_URL = "https://kzyxwnvjhojzayregxgc.supabase.co"
SUPABASE_ANON_KEY = "sb_publishable_SEzzFIpvvqv8fLvtphWfdA_8pnzVdQM"
DORM_NAME = "6号楼-225"
TEST_SIZE = 20


def headers(extra: dict | None = None) -> dict:
    result = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Accept": "application/json",
    }
    if extra:
        result.update(extra)
    return result


def request(method: str, path: str, body: object | None = None, prefer: str | None = None):
    data = None
    extra = {}
    if body is not None:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        extra["Content-Type"] = "application/json; charset=utf-8"
    if prefer:
        extra["Prefer"] = prefer

    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/{path}",
        data=data,
        headers=headers(extra),
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            text = response.read().decode("utf-8")
            return response.status, json.loads(text) if text else None
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode("utf-8", errors="replace")


def rpc(function_name: str, body: dict):
    return request("POST", f"rpc/{function_name}", body)


def load_test_students() -> list[dict]:
    text = Path("assets/dorm-data.js").read_text(encoding="utf-8")
    students_json = text.split("window.ALLOWED_STUDENTS = ", 1)[1].rsplit(";", 1)[0]
    students = json.loads(students_json)
    return [student for student in students if student["gender"] == "男"][:TEST_SIZE]


def find_dorm_id() -> str:
    encoded_name = urllib.parse.quote(DORM_NAME, safe="")
    status, body = request("GET", f"dorms?select=id,name,capacity&name=eq.{encoded_name}")
    if status >= 400:
        raise RuntimeError(f"cannot read dorms: {status} {body}")
    if not body:
        raise RuntimeError(f"cannot find dorm: {DORM_NAME}")
    return body[0]["id"]


def choose(student: dict, dorm_id: str):
    status, body = rpc(
        "choose_dorm",
        {
            "p_name": student["name"],
            "p_gender": student["gender"],
            "p_student_id": student["student_id"],
            "p_dorm_id": dorm_id,
        },
    )
    return {
        "student_id": student["student_id"],
        "name": student["name"],
        "http_status": status,
        "body": body,
        "status": body.get("status") if isinstance(body, dict) else f"http_{status}",
    }


def delete_for_students(table: str, column: str, student_ids: list[str]):
    deleted = []
    errors = []
    for student_id in student_ids:
        status, body = request(
            "DELETE",
            f"{table}?{column}=eq.{urllib.parse.quote(student_id, safe='')}",
            prefer="return=representation",
        )
        if status >= 400:
            errors.append({"student_id": student_id, "status": status, "body": body})
        else:
            deleted.append({"student_id": student_id, "rows": len(body or [])})
    return deleted, errors


def fetch_records(student_ids: list[str]):
    joined = ",".join(student_ids)
    status, body = request(
        "GET",
        f"records?select=id,student_id,name,dorm_id&student_id=in.({joined})",
    )
    return status, body


def fetch_logs(student_ids: list[str]):
    joined = ",".join(student_ids)
    status, body = request(
        "GET",
        f"audit_log?select=id,student_id,student_name,action,new_dorm_name&student_id=in.({joined})",
    )
    return status, body


def main() -> None:
    students = load_test_students()
    student_ids = [student["student_id"] for student in students]
    dorm_id = find_dorm_id()

    with concurrent.futures.ThreadPoolExecutor(max_workers=TEST_SIZE) as executor:
        futures = [executor.submit(choose, student, dorm_id) for student in students]
        results = [future.result() for future in concurrent.futures.as_completed(futures)]

    records_status, records_before_cleanup = fetch_records(student_ids)
    logs_status, logs_before_cleanup = fetch_logs(student_ids)
    deleted_records, record_delete_errors = delete_for_students(
        "records", "student_id", student_ids
    )
    deleted_logs, log_delete_errors = delete_for_students(
        "audit_log", "student_id", student_ids
    )
    records_after_status, records_after_cleanup = fetch_records(student_ids)
    logs_after_status, logs_after_cleanup = fetch_logs(student_ids)

    print(
        json.dumps(
            {
                "dorm": {"id": dorm_id, "name": DORM_NAME},
                "attempted": len(results),
                "result_counts": Counter(result["status"] for result in results),
                "results": sorted(results, key=lambda item: item["student_id"]),
                "records_before_cleanup": {
                    "status": records_status,
                    "rows": records_before_cleanup,
                },
                "logs_before_cleanup": {
                    "status": logs_status,
                    "rows": logs_before_cleanup,
                },
                "deleted_records": deleted_records,
                "record_delete_errors": record_delete_errors,
                "deleted_logs": deleted_logs,
                "log_delete_errors": log_delete_errors,
                "records_after_cleanup": {
                    "status": records_after_status,
                    "rows": records_after_cleanup,
                },
                "logs_after_cleanup": {
                    "status": logs_after_status,
                    "rows": logs_after_cleanup,
                },
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
