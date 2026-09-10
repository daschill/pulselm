"""Random two-dot / ShotResult inputs drive shipped functions, not a second oracle."""

from __future__ import annotations

import math
import random

import pytest

from range_landing import landing_from_shot, landing_yd
from shot_ui import hud_from_shot
from store import build_shot_result
from vision import (
    MM_S_TO_MPH,
    estimate_carry_total_yd,
    hla_deg_from_blob_sizes,
    metrics_from_dots,
)

SEED = 20260909
N = 64


def test_random_two_dots_speed_vla_carry_match_shipped():
    rng = random.Random(SEED)
    for _ in range(N):
        x1 = rng.uniform(40.0, 400.0)
        y1 = rng.uniform(80.0, 700.0)
        dx = rng.uniform(8.0, 180.0)
        dy_up = rng.uniform(-80.0, 120.0)
        mm = rng.uniform(0.8, 3.2)
        gap = 0.002
        d1 = (x1, y1)
        d2 = (x1 + dx, y1 - dy_up)
        got = metrics_from_dots(d1, d2, mm, pulse_gap_s=gap)
        px = math.hypot(dx, dy_up)
        assert got["ball_speed_mph"] == pytest.approx(px * mm / gap * MM_S_TO_MPH)
        assert got["vla_deg"] == pytest.approx(math.degrees(math.atan2(dy_up, dx)))
        carry, total = estimate_carry_total_yd(got["ball_speed_mph"], got["vla_deg"])
        assert got["carry_yd_est"] == carry
        assert got["total_yd_est"] == total
        assert got["hla_deg"] is None
        assert got["spin_rpm"] is None
        assert got["club_speed_mph"] is None
        land = landing_yd(got["carry_yd_est"], got["hla_deg"])
        assert land["along_yd"] == pytest.approx(got["carry_yd_est"])
        assert land["offline_yd"] == 0.0
        assert land["on_line"] is True


def test_random_shotresult_landing_and_hud():
    rng = random.Random(SEED + 1)
    for i in range(N):
        speed = rng.uniform(40.0, 190.0)
        vla = rng.uniform(-5.0, 28.0)
        carry, total = estimate_carry_total_yd(speed, vla)
        hla = None if rng.random() < 0.55 else rng.uniform(-18.0, 18.0)
        shot = build_shot_result(
            shot_id=f"shot_{i + 1:05d}",
            unix_ts=1.0 + i,
            ok=True,
            ball_speed_mph=speed,
            vla_deg=vla,
            hla_deg=hla,
            carry_yd_est=carry,
            total_yd_est=total,
            pulse_gap_s=0.002,
        )
        assert shot["spin_rpm"] is None
        assert shot["club_speed_mph"] is None
        land = landing_from_shot(shot)
        expected = landing_yd(shot["carry_yd_est"], shot["hla_deg"])
        assert land["along_yd"] == expected["along_yd"]
        assert land["offline_yd"] == expected["offline_yd"]
        assert land["on_line"] == expected["on_line"]
        hud = hud_from_shot(shot)
        assert hud["landing"]["along_yd"] == land["along_yd"]
        if shot["hla_deg"] is None:
            assert hud["hla_string"] == "—"
        else:
            assert hud["hla_string"] != "—"
            assert hud["hla_string"] != "0" or shot["hla_deg"] == 0.0


def test_random_hla_photometry_null_below_floor():
    rng = random.Random(SEED + 2)
    for _ in range(N):
        d1 = rng.uniform(8.0, 28.0)
        d2 = d1 + rng.uniform(-0.9, 0.9)
        dx = rng.uniform(20.0, 120.0)
        mm = rng.uniform(1.2, 2.4)
        cam = rng.uniform(1500.0, 4000.0)
        hla = hla_deg_from_blob_sizes(d1, d2, dx, mm, cam)
        assert hla is None
        wide = hla_deg_from_blob_sizes(d1, d1 + 3.5, dx, mm, cam)
        assert wide is not None
