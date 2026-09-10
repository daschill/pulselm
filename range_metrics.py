"""Trackman/GSPro-style range tiles derived from a ShotResult.

Does not invent spin_rpm. Smash/apex/hang/landing angle come from measured
launch + the same flight model as carry.
"""

from __future__ import annotations

import math
from typing import Any, Mapping, Optional

from ball_flight import simulate_flight
from range_landing import landing_from_shot

CLUBS = (
    "Dr",
    "3W",
    "5W",
    "4i",
    "5i",
    "6i",
    "7i",
    "8i",
    "9i",
    "PW",
    "GW",
    "SW",
    "LW",
)

GAMES = ("practice", "closest", "longest", "random")


def smash_factor(ball_speed_mph: Optional[float], club_speed_mph: Optional[float]) -> Optional[float]:
    if ball_speed_mph is None or club_speed_mph is None or club_speed_mph <= 1e-6:
        return None
    return float(ball_speed_mph) / float(club_speed_mph)


def dist_to_pin_yd(along_yd: Optional[float], offline_yd: Optional[float], pin_yd: float) -> Optional[float]:
    if along_yd is None:
        return None
    off = 0.0 if offline_yd is None else float(offline_yd)
    da = float(along_yd) - float(pin_yd)
    return math.hypot(da, off)


def tiles_from_shot(shot: Mapping[str, Any], *, pin_yd: float = 250.0) -> dict[str, Any]:
    speed = shot.get("ball_speed_mph")
    vla = shot.get("vla_deg")
    club = shot.get("club_speed_mph")
    land = landing_from_shot(dict(shot))
    sim = {"apex_yd": None, "hang_time_s": None, "land_angle_deg": None}
    if speed is not None and vla is not None and float(speed) > 0 and float(vla) > 0:
        spin = shot.get("spin_rpm")
        sim = simulate_flight(float(speed), float(vla), backspin_rpm=spin)
    return {
        "ball_speed_mph": speed,
        "vla_deg": vla,
        "hla_deg": shot.get("hla_deg"),
        "spin_rpm": shot.get("spin_rpm"),
        "club_speed_mph": club,
        "smash": smash_factor(speed, club),
        "carry_yd_est": shot.get("carry_yd_est"),
        "total_yd_est": shot.get("total_yd_est"),
        "along_yd": land.get("along_yd"),
        "offline_yd": land.get("offline_yd"),
        "apex_yd": sim.get("apex_yd"),
        "hang_time_s": sim.get("hang_time_s"),
        "land_angle_deg": sim.get("land_angle_deg"),
        "pin_yd": pin_yd,
        "dist_to_pin_yd": dist_to_pin_yd(land.get("along_yd"), land.get("offline_yd"), pin_yd),
        "curve_yd": land.get("offline_yd"),
    }


def closest_to_pin(shots: list[Mapping[str, Any]], pin_yd: float) -> Optional[dict[str, Any]]:
    best = None
    best_d = None
    for s in shots:
        if not s.get("ok"):
            continue
        tiles = tiles_from_shot(s, pin_yd=pin_yd)
        d = tiles.get("dist_to_pin_yd")
        if d is None:
            continue
        if best_d is None or d < best_d:
            best_d = d
            best = {"shot_id": s.get("shot_id"), "dist_to_pin_yd": d, "along_yd": tiles.get("along_yd")}
    return best


def longest_drive(shots: list[Mapping[str, Any]]) -> Optional[dict[str, Any]]:
    best = None
    best_c = None
    for s in shots:
        c = s.get("carry_yd_est")
        if not s.get("ok") or c is None:
            continue
        if best_c is None or float(c) > best_c:
            best_c = float(c)
            best = {"shot_id": s.get("shot_id"), "carry_yd_est": best_c}
    return best
