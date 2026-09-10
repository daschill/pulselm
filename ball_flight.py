"""Indoor carry/total from measured ball speed + VLA.

Spin is NOT measured on unmarked dual-strobe IR. A typical-amateur backspin
prior is used only inside this integrator so carry is not a vacuum parabola.
ShotResult.spin_rpm stays JSON null.
"""

from __future__ import annotations

import math
from typing import Optional

G = 9.80665
MPH_TO_MPS = 0.44704
M_TO_YD = 1.0936132983377078
BALL_MASS_KG = 0.04593
BALL_RADIUS_M = 0.021335
AIR_DENSITY = 1.184  # ~20 C indoor
REF_AREA = math.pi * BALL_RADIUS_M * BALL_RADIUS_M


def typical_backspin_rpm(ball_speed_mph: float, vla_deg: float) -> float:
    """Internal prior. Never serialized as spin_rpm.

    High-speed/low-loft (driver) ~2.2–3.2k rpm; wedges higher.
    """
    s = float(ball_speed_mph)
    vla = max(float(vla_deg), 0.0)
    if s >= 125.0:
        rpm = 2800.0 - 15.0 * (s - 150.0) + 30.0 * (vla - 12.0)
        return max(1800.0, min(4200.0, rpm))
    rpm = 6200.0 - 25.0 * (s - 90.0) + 70.0 * (vla - 24.0)
    return max(3500.0, min(11000.0, rpm))


def simulate_flight(
    ball_speed_mph: float,
    vla_deg: float,
    *,
    backspin_rpm: Optional[float] = None,
    dt: float = 0.002,
) -> dict:
    """Full trajectory extras used by Trackman-style range tiles.

    apex_yd, hang_time_s, land_angle_deg. Carry/total same as estimate_carry_total_yd.
    """
    empty = {
        "carry_yd": 0.0,
        "total_yd": 0.0,
        "apex_yd": 0.0,
        "hang_time_s": 0.0,
        "land_angle_deg": None,
    }
    if ball_speed_mph <= 0 or vla_deg <= 0:
        return empty
    v0 = float(ball_speed_mph) * MPH_TO_MPS
    theta = math.radians(float(vla_deg))
    if v0 <= 0 or theta <= 0:
        return empty
    spin = typical_backspin_rpm(ball_speed_mph, vla_deg) if backspin_rpm is None else float(backspin_rpm)
    if spin < 0:
        spin = 0.0
    omega = spin * 2.0 * math.pi / 60.0
    vx = v0 * math.cos(theta)
    vy = v0 * math.sin(theta)
    x = 0.0
    y = 0.0
    apex_m = 0.0
    t = 0.0
    landed = False
    steps = int(10.0 / dt)
    for _ in range(steps):
        v = math.hypot(vx, vy)
        if v < 0.4:
            break
        s_param = min(0.35, BALL_RADIUS_M * omega / v)
        cd = 0.235 + 0.07 * s_param
        cl = min(0.28, 0.11 + 1.25 * s_param)
        q = 0.5 * AIR_DENSITY * REF_AREA * v
        ax = (-q * cd * vx + q * cl * (-vy)) / BALL_MASS_KG
        ay = -G + (-q * cd * vy + q * cl * vx) / BALL_MASS_KG
        vx += ax * dt
        vy += ay * dt
        x_next = x + vx * dt
        y_next = y + vy * dt
        t += dt
        if y_next > apex_m:
            apex_m = y_next
        if y_next < 0.0 and x_next > 0.5:
            frac = y / (y - y_next) if y_next != y else 1.0
            x = x + frac * (x_next - x)
            t -= dt * (1.0 - frac)
            landed = True
            break
        x, y = x_next, y_next
    carry_yd = max(0.0, x * M_TO_YD)
    roll = 0.11 * max(0.0, 1.0 - float(vla_deg) / 42.0)
    if not landed and y > 0:
        roll *= 0.5
    land_angle = math.degrees(math.atan2(-vy, vx)) if landed else None
    return {
        "carry_yd": carry_yd,
        "total_yd": carry_yd * (1.0 + roll),
        "apex_yd": max(0.0, apex_m * M_TO_YD),
        "hang_time_s": max(0.0, t),
        "land_angle_deg": land_angle,
    }


def estimate_carry_total_yd(
    ball_speed_mph: float,
    vla_deg: float,
    *,
    backspin_rpm: Optional[float] = None,
    dt: float = 0.002,
) -> tuple[float, float]:
    """2D trajectory with drag + lift from a spin *prior*.

    Non-positive VLA from a ground tee → carry 0 (not a behind-the-camera range).
    """
    sim = simulate_flight(
        ball_speed_mph, vla_deg, backspin_rpm=backspin_rpm, dt=dt
    )
    return sim["carry_yd"], sim["total_yd"]
