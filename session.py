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
    from range_metrics import closest_to_pin, longest_drive

    longest = longest_drive(shots)
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
        "longest": longest,
        "dispersion": _dispersion(shots),
    }


def _dispersion(shots: list[dict[str, Any]]) -> dict[str, Any]:
    from range_landing import landing_from_shot

    pts = []
    for s in shots:
        if not s.get("ok"):
            continue
        land = landing_from_shot(s)
        if land.get("along_yd") is None:
            continue
        pts.append((float(land["along_yd"]), float(land.get("offline_yd") or 0.0)))
    if not pts:
        return {"n": 0, "along_mean": None, "offline_mean": None, "radius_yd": None}
    n = len(pts)
    am = sum(p[0] for p in pts) / n
    om = sum(p[1] for p in pts) / n
    if n < 2:
        return {"n": n, "along_mean": am, "offline_mean": om, "radius_yd": None}
    var = sum((p[0] - am) ** 2 + (p[1] - om) ** 2 for p in pts) / (n - 1)
    return {
        "n": n,
        "along_mean": am,
        "offline_mean": om,
        "radius_yd": math.sqrt(var),
    }
