"""Range practice tiles: smash, apex, hang, closest-to-pin, longest drive."""

from __future__ import annotations

import pytest

from ball_flight import simulate_flight
from range_metrics import closest_to_pin, longest_drive, smash_factor, tiles_from_shot
from store import build_shot_result


def test_smash_and_apex_for_driver():
    assert smash_factor(147.5, 98.2) == pytest.approx(147.5 / 98.2)
    assert smash_factor(147.5, None) is None
    sim = simulate_flight(150.0, 12.0)
    assert sim["apex_yd"] > 10.0
    assert sim["hang_time_s"] > 2.0
    assert sim["land_angle_deg"] is not None
    assert sim["carry_yd"] == pytest.approx(sim["carry_yd"])


def test_tiles_dist_to_pin():
    shot = build_shot_result(
        shot_id="shot_00001",
        unix_ts=1.0,
        ok=True,
        ball_speed_mph=150.0,
        vla_deg=12.0,
        hla_deg=0.0,
        club_speed_mph=100.0,
        carry_yd_est=240.0,
        total_yd_est=255.0,
    )
    tiles = tiles_from_shot(shot, pin_yd=250.0)
    assert tiles["smash"] == pytest.approx(1.5)
    assert tiles["dist_to_pin_yd"] == pytest.approx(10.0)
    assert tiles["offline_yd"] == 0.0


def test_closest_and_longest():
    shots = []
    for i, carry in enumerate((180.0, 240.0, 210.0)):
        shots.append(
            build_shot_result(
                shot_id=f"shot_{i+1:05d}",
                unix_ts=float(i),
                ok=True,
                ball_speed_mph=140.0,
                vla_deg=12.0,
                carry_yd_est=carry,
            )
        )
    ctp = closest_to_pin(shots, 200.0)
    assert ctp is not None
    assert ctp["shot_id"] == "shot_00003"
    lng = longest_drive(shots)
    assert lng is not None
    assert lng["shot_id"] == "shot_00002"
    assert lng["carry_yd_est"] == 240.0
