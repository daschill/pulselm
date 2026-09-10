"""24 GHz CW Doppler math. No GPIO in --demo.

v_radial = fd * c / (2 * f0). If the module sits behind the tee looking
downrange, ball speed is v_radial / cos(approach_angle).
"""

from __future__ import annotations

from typing import Optional

C_MPS = 299_792_458.0
MPH_PER_MPS = 2.2369362920544
# ISM 24 GHz band center used by cheap CW modules (CDM324-class).
F0_HZ = 24.125e9


def radial_speed_mps(doppler_hz: float, f0_hz: float = F0_HZ) -> float:
    if f0_hz <= 0:
        raise ValueError("f0_hz must be positive")
    return float(doppler_hz) * C_MPS / (2.0 * f0_hz)


def doppler_hz_for_speed_mps(speed_mps: float, f0_hz: float = F0_HZ) -> float:
    return 2.0 * float(speed_mps) * f0_hz / C_MPS


def speed_mph_from_doppler(
    doppler_hz: float,
    *,
    f0_hz: float = F0_HZ,
    approach_angle_deg: float = 0.0,
) -> float:
    """Ball or club speed along the target line, mph."""
    import math

    vr = radial_speed_mps(doppler_hz, f0_hz)
    ang = math.radians(float(approach_angle_deg))
    c = math.cos(ang)
    if abs(c) < 1e-6:
        raise ValueError("approach_angle_deg too close to 90")
    return abs(vr / c) * MPH_PER_MPS


def parse_radar_sample(
    *,
    ball_doppler_hz: Optional[float] = None,
    club_doppler_hz: Optional[float] = None,
    f0_hz: float = F0_HZ,
    approach_angle_deg: float = 0.0,
) -> dict:
    """Turn IF peak frequencies into speeds. Missing peaks stay None."""
    ball = None
    club = None
    if ball_doppler_hz is not None:
        ball = speed_mph_from_doppler(
            ball_doppler_hz, f0_hz=f0_hz, approach_angle_deg=approach_angle_deg
        )
    if club_doppler_hz is not None:
        club = speed_mph_from_doppler(
            club_doppler_hz, f0_hz=f0_hz, approach_angle_deg=approach_angle_deg
        )
    smash = None
    if ball is not None and club is not None and club > 1e-6:
        smash = ball / club
    return {
        "ball_speed_mph": ball,
        "club_speed_mph": club,
        "smash": smash,
        "f0_hz": f0_hz,
    }
