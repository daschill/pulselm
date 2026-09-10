"""Shipped carry model: drag+lift prior, spin JSON stays null."""

from __future__ import annotations

import pytest

from ball_flight import estimate_carry_total_yd, typical_backspin_rpm
from session import summarize_session
from store import build_shot_result
from vision import estimate_carry_total_yd as vision_carry
from vision import metrics_from_dots


def test_driver_carry_in_amateur_band():
    carry, total = estimate_carry_total_yd(150.0, 12.0)
    assert 210.0 <= carry <= 290.0
    assert total > carry
    assert typical_backspin_rpm(150.0, 12.0) == pytest.approx(2800.0, abs=200.0)


def test_tour_speed_carries_longer_than_amateur():
    a, _ = estimate_carry_total_yd(150.0, 12.0)
    t, _ = estimate_carry_total_yd(167.0, 11.0)
    assert t > a


def test_wedge_shorter_than_driver():
    d, _ = estimate_carry_total_yd(150.0, 12.0)
    w, _ = estimate_carry_total_yd(80.0, 32.0)
    assert w < d
    assert 70.0 <= w <= 160.0


def test_nonpositive_vla_is_tee():
    assert estimate_carry_total_yd(150.0, 0.0) == (0.0, 0.0)
    assert estimate_carry_total_yd(150.0, -4.0) == (0.0, 0.0)
    assert estimate_carry_total_yd(0.0, 12.0) == (0.0, 0.0)


def test_vision_reexports_same_carry():
    assert vision_carry(150.0, 12.0) == estimate_carry_total_yd(150.0, 12.0)


def test_metrics_do_not_publish_spin_prior():
    m = metrics_from_dots((180.0, 420.0), (255.0, 395.0), 1.8)
    assert m["spin_rpm"] is None
    assert m["club_speed_mph"] is None
    assert m["carry_yd_est"] == estimate_carry_total_yd(m["ball_speed_mph"], m["vla_deg"])[0]


def test_session_summary_means():
    shots = []
    for i, speed in enumerate((140.0, 150.0, 160.0)):
        c, t = estimate_carry_total_yd(speed, 12.0)
        shots.append(
            build_shot_result(
                shot_id=f"shot_{i+1:05d}",
                unix_ts=float(i),
                ok=True,
                ball_speed_mph=speed,
                vla_deg=12.0,
                carry_yd_est=c,
                total_yd_est=t,
            )
        )
    s = summarize_session(shots)
    assert s["shot_count"] == 3
    assert s["ball_speed_mph_mean"] == pytest.approx(150.0)
    assert s["ball_speed_mph_max"] == pytest.approx(160.0)
    assert s["ball_speed_mph_sd"] == pytest.approx(10.0)
    assert s["not_measured"][0] == "hla_deg"
    assert shots[0]["spin_rpm"] is None
