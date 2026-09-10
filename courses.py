"""OpenGolfAPI course catalog (ODbL). Scorecards and yardages we can use.

Not GSPro/E6 3D meshes (those licenses stay in those apps). This is
facts: name, par, hole yardages — attributed to OpenGolfAPI / OSM.
"""

from __future__ import annotations

import json
import urllib.parse
import urllib.request
from typing import Any, Callable, Optional

BASE = "https://api.opengolfapi.org"
ATTRIBUTION = (
    "Contains data from OpenGolfAPI (opengolfapi.org) / "
    "© OpenStreetMap contributors (ODbL 1.0)"
)

# Public / municipal courses with scorecards in the open dataset.
FEATURED = (
    ("1d930d4d-7beb-48e6-9346-f3db01b70172", "Bethpage Black"),
    ("babc6173-2c9c-44ae-bd72-b5a35d8dc211", "Bethpage Red"),
    ("40977ee8-33ee-4195-b6a2-99a4ca83c2bc", "Pebble Beach Golf Links"),
)

FetchFn = Callable[[str], dict[str, Any]]


def _default_fetch(url: str) -> dict[str, Any]:
    req = urllib.request.Request(url, headers={"User-Agent": "PulseLM/1.0"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))


def search_courses(q: str, *, limit: int = 15, fetch: Optional[FetchFn] = None) -> dict[str, Any]:
    fn = fetch or _default_fetch
    qs = urllib.parse.urlencode({"q": q, "limit": int(limit)})
    data = fn(f"{BASE}/v1/courses/search?{qs}")
    rows = []
    for c in data.get("courses") or []:
        rows.append(
            {
                "id": c.get("id"),
                "name": c.get("name") or c.get("course_name"),
                "city": c.get("city"),
                "state": c.get("state"),
                "type": c.get("type") or c.get("course_type"),
                "par": c.get("par") or c.get("par_total"),
            }
        )
    return {
        "ok": True,
        "query": q,
        "courses": rows,
        "total": data.get("total", len(rows)),
        "attribution": data.get("_attribution") or ATTRIBUTION,
        "license": data.get("_license") or "ODbL-1.0",
    }


def pin_yards_from_hole(hole: dict[str, Any]) -> Optional[int]:
    yards = hole.get("yardages") or {}
    for key in ("blue", "white", "gold", "green", "web", "red"):
        v = yards.get(key)
        if isinstance(v, (int, float)) and v > 0:
            return int(v)
    if isinstance(hole.get("yards"), (int, float)):
        return int(hole["yards"])
    return None


def holes_as_targets(payload: dict[str, Any]) -> list[dict[str, Any]]:
    holes = payload.get("holes") or payload.get("scorecard") or []
    out = []
    for h in holes:
        num = h.get("number") if h.get("number") is not None else h.get("hole")
        par = h.get("par")
        pin = pin_yards_from_hole(h)
        if num is None:
            continue
        out.append({"hole": int(num), "par": par, "pin_yd": pin})
    out.sort(key=lambda r: r["hole"])
    return out


def course_with_holes(course_id: str, *, fetch: Optional[FetchFn] = None) -> dict[str, Any]:
    fn = fetch or _default_fetch
    detail = fn(f"{BASE}/v1/courses/{course_id}")
    try:
        holes_payload = fn(f"{BASE}/v1/courses/{course_id}/holes")
    except Exception:
        holes_payload = {"holes": detail.get("scorecard") or []}
    targets = holes_as_targets(holes_payload if holes_payload.get("holes") else detail)
    if not targets:
        targets = holes_as_targets(detail)
    return {
        "ok": True,
        "id": detail.get("id") or course_id,
        "name": detail.get("name") or detail.get("course_name"),
        "city": detail.get("city"),
        "state": detail.get("state"),
        "type": detail.get("type"),
        "par": detail.get("par"),
        "holes": targets,
        "attribution": detail.get("_attribution") or ATTRIBUTION,
        "license": detail.get("_license") or "ODbL-1.0",
    }


def featured(*, fetch: Optional[FetchFn] = None) -> dict[str, Any]:
    rows = []
    for cid, label in FEATURED:
        try:
            rows.append(course_with_holes(cid, fetch=fetch))
        except Exception:
            rows.append({"ok": False, "id": cid, "name": label, "holes": []})
    return {
        "ok": True,
        "courses": rows,
        "attribution": ATTRIBUTION,
        "license": "ODbL-1.0",
        "note": "Scorecards/yardages only. No 3D meshes. GSPro/E6 course files are not licensed here.",
    }
