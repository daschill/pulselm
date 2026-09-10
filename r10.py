"""Garmin Approach R10 → pulselm.shot.v1.

The R10 has no public SDK. Community bridges (gsp-r10-adapter, GSPro Connect)
speak GSPro OpenConnect V1 on TCP 921. The R10 E6 path sends SetBallData /
SetClubData / SendShot JSON. Both map here.

OpenConnect BallData.Speed is mph. E6 BallData.BallSpeed from the R10 is m/s.
"""

from __future__ import annotations

import math
from typing import Any, Optional

from ball_flight import estimate_carry_total_yd

MPS_TO_MPH = 2.2369362920544


def _f(v: Any) -> Optional[float]:
    if v is None or v == "":
        return None
    try:
        x = float(v)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(x):
        return None
    return x


def _spin_axis_deg(raw: Optional[float]) -> Optional[float]:
    if raw is None:
        return None
    a = float(raw)
    if a > 180.0:
        a -= 360.0
    if a <= -180.0:
        a += 360.0
    return a


def _is_heartbeat(payload: dict[str, Any]) -> bool:
    opts = payload.get("ShotDataOptions") or {}
    if opts.get("IsHeartBeat") is True:
        return True
    if payload.get("Type") in ("Heartbeat", "HeartBeat"):
        return True
    return False


def from_openconnect(payload: dict[str, Any]) -> Optional[dict[str, Any]]:
    """GSPro OpenConnect V1 (what gsp-r10-adapter sends to :921)."""
    if _is_heartbeat(payload):
        return None
    ball = payload.get("BallData") or {}
    club = payload.get("ClubData") or {}
    opts = payload.get("ShotDataOptions") or {}
    if opts.get("ContainsBallData") is False and not ball.get("Speed"):
        return None
    speed = _f(ball.get("Speed"))
    vla = _f(ball.get("VLA") if ball.get("VLA") is not None else ball.get("LaunchAngle"))
    hla = _f(ball.get("HLA") if ball.get("HLA") is not None else ball.get("LaunchDirection"))
    spin = _f(ball.get("TotalSpin") if ball.get("TotalSpin") is not None else ball.get("BackSpin"))
    axis = _spin_axis_deg(_f(ball.get("SpinAxis")))
    carry = _f(ball.get("CarryDistance"))
    has_club = opts.get("ContainsClubData") is True
    club_spd = _f(club.get("Speed") if club.get("Speed") is not None else club.get("SpeedAtImpact"))
    face = _f(club.get("FaceToTarget") if club.get("FaceToTarget") is not None else club.get("Face"))
    path = _f(club.get("Path"))
    if not has_club:
        club_spd = None
        face = None
        path = None
    elif club_spd == 0.0:
        club_spd = None
    if speed is None:
        return None
    if vla is not None:
        est_carry, est_total = estimate_carry_total_yd(speed, vla)
    else:
        est_carry, est_total = None, None
    if carry is None:
        carry, total = est_carry, est_total
    else:
        total = est_total if est_total is not None else carry
    return {
        "ball_speed_mph": speed,
        "vla_deg": vla,
        "hla_deg": hla,
        "spin_rpm": spin,
        "spin_axis_deg": axis,
        "club_speed_mph": club_spd,
        "face_deg": face,
        "path_deg": path,
        "carry_yd_est": carry,
        "total_yd_est": total,
        "device": payload.get("DeviceID") or "Garmin R10",
        "shot_number": payload.get("ShotNumber"),
        "source": "openconnect",
    }


def from_e6_ball(ball: dict[str, Any]) -> dict[str, Any]:
    """R10 E6 SetBallData. Speeds are m/s."""
    mps = _f(ball.get("BallSpeed") if ball.get("BallSpeed") is not None else ball.get("Speed"))
    speed = None if mps is None else mps * MPS_TO_MPH
    return {
        "ball_speed_mph": speed,
        "vla_deg": _f(ball.get("LaunchAngle") if ball.get("LaunchAngle") is not None else ball.get("VLA")),
        "hla_deg": _f(ball.get("LaunchDirection") if ball.get("LaunchDirection") is not None else ball.get("HLA")),
        "spin_rpm": _f(ball.get("TotalSpin")),
        "spin_axis_deg": _spin_axis_deg(_f(ball.get("SpinAxis"))),
        "source": "e6",
    }


def from_e6_club(club: dict[str, Any]) -> dict[str, Any]:
    mps = _f(
        club.get("ClubHeadSpeed")
        if club.get("ClubHeadSpeed") is not None
        else club.get("Speed")
    )
    return {
        "club_speed_mph": None if mps is None else mps * MPS_TO_MPH,
        "face_deg": _f(club.get("ClubAngleFace") if club.get("ClubAngleFace") is not None else club.get("FaceToTarget")),
        "path_deg": _f(club.get("ClubAnglePath") if club.get("ClubAnglePath") is not None else club.get("Path")),
    }


def complete_e6(ball: dict[str, Any], club: Optional[dict[str, Any]] = None) -> Optional[dict[str, Any]]:
    out = from_e6_ball(ball)
    if out.get("ball_speed_mph") is None:
        return None
    if club:
        out.update({k: v for k, v in from_e6_club(club).items() if v is not None})
    vla = out.get("vla_deg")
    speed = out["ball_speed_mph"]
    if vla is not None:
        carry, total = estimate_carry_total_yd(speed, vla)
        out["carry_yd_est"] = carry
        out["total_yd_est"] = total
    out["device"] = "Garmin R10"
    return out


def shot_from_payload(payload: dict[str, Any]) -> Optional[dict[str, Any]]:
    """Accept OpenConnect, E6 SetBallData, or a completed E6 bundle."""
    if not isinstance(payload, dict):
        return None
    t = payload.get("Type")
    if t == "SetBallData" and isinstance(payload.get("BallData"), dict):
        return complete_e6(payload["BallData"], payload.get("ClubData") if isinstance(payload.get("ClubData"), dict) else None)
    if t == "SetClubData":
        return None  # wait for SendShot / SetBallData
    if payload.get("BallData") and (payload.get("APIversion") or payload.get("DeviceID") or payload.get("ShotNumber") is not None):
        return from_openconnect(payload)
    if payload.get("BallData") and payload.get("Type") in (None, "SendShot", "ShotComplete"):
        ball = payload["BallData"]
        if "BallSpeed" in ball or "LaunchAngle" in ball:
            return complete_e6(ball, payload.get("ClubData") if isinstance(payload.get("ClubData"), dict) else None)
        return from_openconnect(payload)
    return from_openconnect(payload)


def ingest_shot(payload: dict[str, Any], shots_dir=None) -> Optional[dict[str, Any]]:
    """Map a payload, persist ShotResult, return it (or None for heartbeat)."""
    import time

    import numpy as np

    import store

    fields = shot_from_payload(payload)
    if fields is None:
        return None
    sid = store.next_shot_id(shots_dir)
    result = store.build_shot_result(
        shot_id=sid,
        unix_ts=time.time(),
        ok=True,
        ball_speed_mph=fields.get("ball_speed_mph"),
        vla_deg=fields.get("vla_deg"),
        hla_deg=fields.get("hla_deg"),
        spin_rpm=fields.get("spin_rpm"),
        spin_axis_deg=fields.get("spin_axis_deg"),
        club_speed_mph=fields.get("club_speed_mph"),
        face_deg=fields.get("face_deg"),
        path_deg=fields.get("path_deg"),
        carry_yd_est=fields.get("carry_yd_est"),
        total_yd_est=fields.get("total_yd_est"),
        confidence=0.9,
        pulse_gap_s=0.002,
    )
    store.save_shot(
        result=result,
        raw_image=np.zeros((16, 16), dtype=np.uint8),
        meta={
            "source": fields.get("source"),
            "device": fields.get("device"),
            "shot_number": fields.get("shot_number"),
        },
        shots_dir=shots_dir,
    )
    return store.load_result(sid, shots_dir)
