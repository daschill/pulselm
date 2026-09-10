"""Project carry onto range along/offline yards. HLA stays null unless measured."""

from __future__ import annotations

from math import cos, radians, sin
from typing import Any, Optional


def landing_yd(
    carry_yd_est: Optional[float], hla_deg: Optional[float] = None
) -> dict[str, Any]:
    """along = carry if HLA is missing; else carry * cos/sin(HLA)."""
    if carry_yd_est is None:
        return {
            "along_yd": None,
            "offline_yd": None,
            "on_line": hla_deg is None,
        }
    carry = float(carry_yd_est)
    if hla_deg is None:
        return {
            "along_yd": carry,
            "offline_yd": 0.0,
            "on_line": True,
        }
    hla_rad = radians(float(hla_deg))
    return {
        "along_yd": carry * cos(hla_rad),
        "offline_yd": carry * sin(hla_rad),
        "on_line": False,
    }


def landing_from_shot(shot: dict[str, Any]) -> dict[str, Any]:
    out = landing_yd(shot.get("carry_yd_est"), shot.get("hla_deg"))
    out["shot_id"] = shot.get("shot_id")
    out["carry_yd_est"] = shot.get("carry_yd_est")
    out["hla_deg"] = shot.get("hla_deg")
    return out
