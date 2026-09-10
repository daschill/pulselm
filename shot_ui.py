"""JSON → display strings for the iOS client contract and the Flask HUD.

Field names stay pulselm.shot.v1 verbatim. Null metrics render as em dash, never "0".
"""

from __future__ import annotations

from typing import Any, Mapping, Optional

from range_landing import landing_from_shot

MISSING = "—"


def format_speed_mph(ball_speed_mph: Optional[float]) -> str:
    if ball_speed_mph is None:
        return MISSING
    return f"{float(ball_speed_mph):.2f}"


def format_vla_deg(vla_deg: Optional[float]) -> str:
    if vla_deg is None:
        return MISSING
    return f"{float(vla_deg):.1f}"


def format_carry_yd(carry_yd_est: Optional[float]) -> str:
    if carry_yd_est is None:
        return MISSING
    return f"{float(carry_yd_est):.0f}"


def hud_from_shot(shot: Mapping[str, Any]) -> dict[str, Any]:
    """Shipped mapping: ShotResult JSON → HUD strings + range landing."""
    speed = format_speed_mph(shot.get("ball_speed_mph"))
    landing = landing_from_shot(shot)
    return {
        "ball_speed_mph": shot.get("ball_speed_mph"),
        "speed_string": speed,
        "vla_string": format_vla_deg(shot.get("vla_deg")),
        "carry_string": format_carry_yd(shot.get("carry_yd_est")),
        "hla_string": MISSING if shot.get("hla_deg") is None else f"{float(shot['hla_deg']):.1f}",
        "spin_string": MISSING if shot.get("spin_rpm") is None else str(shot.get("spin_rpm")),
        "club_string": MISSING if shot.get("club_speed_mph") is None else str(shot.get("club_speed_mph")),
        "shot_id": shot.get("shot_id"),
        "landing": landing,
    }
