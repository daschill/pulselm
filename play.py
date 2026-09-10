"""Playable 18-hole round from OpenGolfAPI scorecards.

Each hole's pin is that hole's tee yardage. A launch-monitor shot reduces
remaining yards by carry/along. Inside GIMME_YD the hole is conceded +1 putt.
This is on-course practice (Trackman/GSPro style), not a licensed 3D mesh.
"""

from __future__ import annotations

import json
import math
import time
from pathlib import Path
from typing import Any, Optional

from courses import course_with_holes
from range_landing import landing_from_shot

GIMME_YD = 3.0
MAX_STROKES = 8


def _round_path(shots_dir: Path) -> Path:
    return Path(shots_dir) / "round.json"


def load_round(shots_dir: Path) -> Optional[dict[str, Any]]:
    path = _round_path(shots_dir)
    if not path.is_file():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def save_round(round_doc: dict[str, Any], shots_dir: Path) -> dict[str, Any]:
    path = _round_path(shots_dir)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(round_doc, indent=2) + "\n", encoding="utf-8")
    return round_doc


def _hole_state(course: dict[str, Any], hole_num: int) -> dict[str, Any]:
    holes = course.get("holes") or []
    hole = next((h for h in holes if int(h["hole"]) == int(hole_num)), None)
    if hole is None:
        raise ValueError(f"no hole {hole_num}")
    pin = hole.get("pin_yd") or {3: 150, 4: 380, 5: 500}.get(int(hole.get("par") or 4), 350)
    return {
        "hole": int(hole["hole"]),
        "par": hole.get("par"),
        "pin_yd": int(pin),
        "remaining_yd": float(pin),
        "strokes": 0,
        "finished": False,
        "shots": [],
    }


def start_round(
    course_id: str,
    shots_dir: Path,
    *,
    fetch=None,
    max_holes: int = 18,
) -> dict[str, Any]:
    course = course_with_holes(course_id, fetch=fetch)
    holes = list(course.get("holes") or [])
    if not holes:
        raise ValueError("course has no holes")
    n = max(1, min(int(max_holes), len(holes)))
    holes = holes[:n]
    current = _hole_state(course, holes[0]["hole"])
    doc = {
        "ok": True,
        "playing": True,
        "course_id": course["id"],
        "course_name": course.get("name"),
        "city": course.get("city"),
        "state": course.get("state"),
        "par": course.get("par"),
        "attribution": course.get("attribution"),
        "license": course.get("license"),
        "holes": holes,
        "max_holes": n,
        "scorecard": [],
        "current": current,
        "to_par": 0,
        "thru": 0,
        "started_ts": time.time(),
    }
    return save_round(doc, shots_dir)


def apply_shot(shot: dict[str, Any], shots_dir: Path) -> Optional[dict[str, Any]]:
    doc = load_round(shots_dir)
    if not doc or not doc.get("playing"):
        return None
    cur = doc["current"]
    if cur.get("finished"):
        return doc
    land = landing_from_shot(shot)
    along = land.get("along_yd")
    if along is None:
        along = shot.get("carry_yd_est") or 0.0
    offline = abs(float(land.get("offline_yd") or 0.0))
    remain = float(cur["remaining_yd"])
    toward = min(remain, max(0.0, float(along)))
    leftover_along = remain - toward
    new_remain = math.hypot(leftover_along, offline * 0.35)
    cur["strokes"] = int(cur["strokes"]) + 1
    cur["remaining_yd"] = round(new_remain, 1)
    cur["shots"].append(
        {
            "shot_id": shot.get("shot_id"),
            "carry_yd_est": shot.get("carry_yd_est"),
            "remaining_yd": cur["remaining_yd"],
        }
    )
    if new_remain <= GIMME_YD:
        cur["strokes"] = int(cur["strokes"]) + 1
        _finish_hole(doc, gimme=True)
    elif cur["strokes"] >= MAX_STROKES:
        _finish_hole(doc, gimme=False)
    return save_round(doc, shots_dir)


def gimme(shots_dir: Path) -> dict[str, Any]:
    doc = load_round(shots_dir)
    if not doc:
        raise ValueError("no round")
    cur = doc["current"]
    if not cur.get("finished"):
        cur["strokes"] = int(cur["strokes"]) + 1
        _finish_hole(doc, gimme=True)
    return save_round(doc, shots_dir)


def _finish_hole(doc: dict[str, Any], *, gimme: bool) -> None:
    cur = doc["current"]
    del gimme
    par = int(cur.get("par") or 4)
    strokes = int(cur["strokes"])
    cur["finished"] = True
    cur["remaining_yd"] = 0.0
    rel = strokes - par
    doc["scorecard"].append(
        {
            "hole": cur["hole"],
            "par": par,
            "strokes": strokes,
            "to_par": rel,
        }
    )
    doc["thru"] = len(doc["scorecard"])
    doc["to_par"] = sum(h["to_par"] for h in doc["scorecard"])
    holes = doc.get("holes") or []
    nxt = next((h for h in holes if int(h["hole"]) > int(cur["hole"])), None)
    if nxt is None:
        doc["playing"] = False
        doc["current"]["done_round"] = True
    else:
        doc["current"] = _hole_state({"holes": holes}, nxt["hole"])


def public_view(doc: Optional[dict[str, Any]]) -> dict[str, Any]:
    if not doc:
        return {"ok": True, "playing": False, "round": None}
    cur = doc.get("current") or {}
    return {
        "ok": True,
        "playing": bool(doc.get("playing")),
        "course_id": doc.get("course_id"),
        "course_name": doc.get("course_name"),
        "city": doc.get("city"),
        "state": doc.get("state"),
        "par": doc.get("par"),
        "attribution": doc.get("attribution"),
        "hole": cur.get("hole"),
        "hole_par": cur.get("par"),
        "pin_yd": cur.get("pin_yd"),
        "remaining_yd": cur.get("remaining_yd"),
        "strokes": cur.get("strokes"),
        "finished_hole": cur.get("finished"),
        "thru": doc.get("thru"),
        "to_par": doc.get("to_par"),
        "max_holes": doc.get("max_holes") or len(doc.get("holes") or []),
        "scorecard": doc.get("scorecard") or [],
        "gimme_yd": GIMME_YD,
    }
