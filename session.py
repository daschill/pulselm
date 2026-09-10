"""Session stats from stored ShotResult rows. Budget-LM practice strip."""

from __future__ import annotations

import math
from typing import Any, Iterable, Optional


def _nums(shots: Iterable[dict[str, Any]], key: str) -> list[float]:
    out: list[float] = []
    for s in shots:
        if not s.get("ok"):
            continue
        v = s.get(key)
        if v is None:
            continue
        try:
            x = float(v)
        except (TypeError, ValueError):
            continue
        if math.isfinite(x):
            out.append(x)
    return out


def _mean(xs: list[float]) -> Optional[float]:
    if not xs:
        return None
    return sum(xs) / len(xs)


def _sd(xs: list[float]) -> Optional[float]:
    if len(xs) < 2:
        return None
    m = _mean(xs)
    assert m is not None
    var = sum((x - m) ** 2 for x in xs) / (len(xs) - 1)
    return math.sqrt(var)


def summarize_session(shots: list[dict[str, Any]]) -> dict[str, Any]:
    """Means/SD for measured launch + estimated carry. Spin/club stay absent."""
    speeds = _nums(shots, "ball_speed_mph")
    vlas = _nums(shots, "vla_deg")
    carrys = _nums(shots, "carry_yd_est")
    n = len(speeds)
    return {
        "ok": True,
        "shot_count": n,
        "ball_speed_mph_mean": _mean(speeds),
        "ball_speed_mph_sd": _sd(speeds),
        "ball_speed_mph_max": max(speeds) if speeds else None,
        "vla_deg_mean": _mean(vlas),
        "vla_deg_sd": _sd(vlas),
        "carry_yd_est_mean": _mean(carrys),
        "carry_yd_est_sd": _sd(carrys),
        "carry_yd_est_max": max(carrys) if carrys else None,
        "measured": ["ball_speed_mph", "vla_deg"],
        "estimated": ["carry_yd_est", "total_yd_est"],
        "not_measured": [
            "hla_deg",
            "spin_rpm",
            "spin_axis_deg",
            "club_speed_mph",
            "face_deg",
            "path_deg",
        ],
    }
