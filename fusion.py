"""Fuse 4× OV9281 dual-strobe + 24 GHz Doppler into pulselm.shot.v1.

Priority:
  ball_speed_mph  radar if present, else side-on two-dot
  vla_deg         side-on two-dot (cam 0)
  hla_deg         stereo pair or face-on cam 2
  club_speed_mph  radar club peak
  path_deg        cam 3 club two-dot
  spin_rpm        only if a ball mark angle pair is given
  face_deg        only if a face estimate is given (markings / club face cam)

Missing stays JSON null. Do not invent radar numbers in --demo.
"""

from __future__ import annotations

from typing import Any, Mapping, Optional, Sequence

from ball_flight import estimate_carry_total_yd
from cameras import (
    club_path_face_deg,
    hla_deg_from_face_on,
    hla_deg_from_stereo_ghosts,
    spin_rpm_from_mark,
)
from radar import parse_radar_sample
from vision import metrics_from_dots


def fuse_shot(
    *,
    side_dot1: Optional[Sequence[float]] = None,
    side_dot2: Optional[Sequence[float]] = None,
    mm_per_px: float = 1.8,
    pulse_gap_s: float = 0.002,
    radar_ball_doppler_hz: Optional[float] = None,
    radar_club_doppler_hz: Optional[float] = None,
    radar_f0_hz: float = 24.125e9,
    radar_approach_angle_deg: float = 0.0,
    stereo_left_dot1: Optional[Sequence[float]] = None,
    stereo_left_dot2: Optional[Sequence[float]] = None,
    stereo_right_dot1: Optional[Sequence[float]] = None,
    stereo_right_dot2: Optional[Sequence[float]] = None,
    stereo_baseline_mm: Optional[float] = None,
    stereo_focal_px: Optional[float] = None,
    face_on_dot1: Optional[Sequence[float]] = None,
    face_on_dot2: Optional[Sequence[float]] = None,
    club_dot1: Optional[Sequence[float]] = None,
    club_dot2: Optional[Sequence[float]] = None,
    mark_angle1_deg: Optional[float] = None,
    mark_angle2_deg: Optional[float] = None,
    face_deg: Optional[float] = None,
) -> dict[str, Any]:
    """Return ShotResult-ready fields plus source tags."""
    vision: Mapping[str, Any] = {}
    if side_dot1 is not None and side_dot2 is not None:
        vision = metrics_from_dots(side_dot1, side_dot2, mm_per_px, pulse_gap_s)

    radar = parse_radar_sample(
        ball_doppler_hz=radar_ball_doppler_hz,
        club_doppler_hz=radar_club_doppler_hz,
        f0_hz=radar_f0_hz,
        approach_angle_deg=radar_approach_angle_deg,
    )

    ball = radar["ball_speed_mph"]
    ball_src = "radar" if ball is not None else None
    if ball is None:
        ball = vision.get("ball_speed_mph")
        if ball is not None:
            ball_src = "dual_strobe"

    vla = vision.get("vla_deg")
    hla = None
    if (
        stereo_left_dot1 is not None
        and stereo_left_dot2 is not None
        and stereo_right_dot1 is not None
        and stereo_right_dot2 is not None
        and stereo_baseline_mm
        and stereo_focal_px
    ):
        hla = hla_deg_from_stereo_ghosts(
            stereo_left_dot1,
            stereo_left_dot2,
            stereo_right_dot1,
            stereo_right_dot2,
            baseline_mm=stereo_baseline_mm,
            focal_px=stereo_focal_px,
            mm_per_px_left=mm_per_px,
            pulse_gap_s=pulse_gap_s,
        )
    if hla is None and face_on_dot1 is not None and face_on_dot2 is not None:
        hla = hla_deg_from_face_on(face_on_dot1, face_on_dot2)

    club = radar["club_speed_mph"]
    path = None
    face = face_deg
    if club_dot1 is not None and club_dot2 is not None:
        path, face_from_club = club_path_face_deg(club_dot1, club_dot2)
        if face is None:
            face = face_from_club

    spin = None
    spin_axis = None
    if mark_angle1_deg is not None and mark_angle2_deg is not None:
        spin = spin_rpm_from_mark(mark_angle1_deg, mark_angle2_deg, pulse_gap_s)

    carry = total = None
    if ball is not None and vla is not None:
        carry, total = estimate_carry_total_yd(ball, vla)

    conf = 0.0
    if ball_src == "radar":
        conf += 0.45
    elif ball_src == "dual_strobe":
        conf += 0.35
    if vla is not None:
        conf += 0.2
    if hla is not None:
        conf += 0.15
    if club is not None:
        conf += 0.1
    if spin is not None:
        conf += 0.1
    conf = min(1.0, conf)

    return {
        "ball_speed_mph": ball,
        "vla_deg": vla,
        "hla_deg": hla,
        "spin_rpm": spin,
        "spin_axis_deg": spin_axis,
        "club_speed_mph": club,
        "face_deg": face,
        "path_deg": path,
        "carry_yd_est": carry,
        "total_yd_est": total,
        "confidence": conf if ball is not None else None,
        "ghost_px": vision.get("ghost_px"),
        "pulse_gap_s": pulse_gap_s,
        "sources": {
            "ball_speed_mph": ball_src,
            "vla_deg": "dual_strobe" if vla is not None else None,
            "hla_deg": "stereo_or_face_on" if hla is not None else None,
            "club_speed_mph": "radar" if club is not None else None,
            "spin_rpm": "ball_mark" if spin is not None else None,
        },
    }
