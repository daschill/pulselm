"""Four OV9281 global-shutter views, one dual-strobe.

Cam 0  side-on (existing two-dot speed/VLA)
Cam 1  side-on stereo mate (baseline along camera Z)
Cam 2  face-on / down-the-line (HLA, face)
Cam 3  high-behind (club path)

Spin needs a visible mark (or dimple lock) between the two 2 µs flashes.
Unmarked IR blobs still cannot yield spin_rpm.
"""

from __future__ import annotations

import math
from typing import Optional, Sequence

from service.pulse import PULSE_GAP_S


def hla_deg_from_face_on(
    dot1: Sequence[float],
    dot2: Sequence[float],
) -> float:
    """Face-on image: +x is offline (right), +y is down.

    Downrange is into the camera, so HLA uses image x vs a calibrated
    downrange scale on that view. With two ghosts 0.002 s apart, HLA is
    atan2(offline, downrange). If the face-on axis is purely image-x vs
    image-y-up as a proxy for downrange (camera slightly elevated), use
    atan2(dx, -dy) when the ball is flying toward the camera.
    """
    dx = float(dot2[0]) - float(dot1[0])
    dy_up = float(dot1[1]) - float(dot2[1])
    return math.degrees(math.atan2(dx, dy_up if abs(dy_up) > 1e-9 else 1e-9))


def stereo_z_mm(
    x_left_px: float,
    x_right_px: float,
    *,
    baseline_mm: float,
    focal_px: float,
) -> Optional[float]:
    disp = float(x_left_px) - float(x_right_px)
    if abs(disp) < 1e-6 or focal_px <= 0 or baseline_mm <= 0:
        return None
    return baseline_mm * focal_px / disp


def hla_deg_from_stereo_ghosts(
    left_dot1: Sequence[float],
    left_dot2: Sequence[float],
    right_dot1: Sequence[float],
    right_dot2: Sequence[float],
    *,
    baseline_mm: float,
    focal_px: float,
    mm_per_px_left: float,
    pulse_gap_s: float = PULSE_GAP_S,
) -> Optional[float]:
    """HLA from a side-on stereo pair of dual-strobe ghosts.

    Downrange velocity from left-image x; offline from stereo Z change.
    """
    z1 = stereo_z_mm(left_dot1[0], right_dot1[0], baseline_mm=baseline_mm, focal_px=focal_px)
    z2 = stereo_z_mm(left_dot2[0], right_dot2[0], baseline_mm=baseline_mm, focal_px=focal_px)
    if z1 is None or z2 is None or pulse_gap_s <= 0:
        return None
    dx_mm = (float(left_dot2[0]) - float(left_dot1[0])) * mm_per_px_left
    dz_mm = z2 - z1
    if abs(dx_mm) < 1e-9 and abs(dz_mm) < 1e-9:
        return None
    return math.degrees(math.atan2(dz_mm, dx_mm))


def spin_rpm_from_mark(
    angle1_deg: float,
    angle2_deg: float,
    pulse_gap_s: float = PULSE_GAP_S,
) -> Optional[float]:
    """Backspin from a visible mark rotating between the two flashes."""
    if pulse_gap_s <= 0:
        return None
    d = (float(angle2_deg) - float(angle1_deg) + 180.0) % 360.0 - 180.0
    return abs(d) / 360.0 / pulse_gap_s * 60.0


def club_path_face_deg(
    club1: Sequence[float],
    club2: Sequence[float],
    *,
    target_axis_deg: float = 0.0,
) -> tuple[Optional[float], Optional[float]]:
    """DTL/high-behind club head two-dot: path vs target; face stays None without markings."""
    dx = float(club2[0]) - float(club1[0])
    dy_up = float(club1[1]) - float(club2[1])
    if abs(dx) < 1e-9 and abs(dy_up) < 1e-9:
        return None, None
    path = math.degrees(math.atan2(dy_up, dx)) - target_axis_deg
    return path, None
