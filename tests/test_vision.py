"""Gating tests: shipped two-dot math, not a reimplementation."""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
import pytest

from calibrate import (
    DEFAULT_MM_PER_PX,
    mm_per_px_from_golf_ball,
    mm_per_px_from_known_length,
)
from service.pulse import FLASH_GAP_US, FLASH_WIDTH_US, PULSE_GAP_S, dual_flash_edges_us
from store import NULL_METRICS, SCHEMA, SHOT_FIELDS, build_shot_result
from vision import (
    GOLF_BALL_DIAMETER_MM,
    analyze_frame,
    find_two_dots,
    metrics_from_dots,
    px_distance,
    render_two_dot_image,
)

# Representative two-dot geometry (image +y down).
DOT1 = (180.0, 420.0)
DOT2 = (255.0, 395.0)
MM_PER_PX = 1.8


def spec_speed_mph(dot1, dot2, mm_per_px, pulse_gap_s=0.002) -> float:
    """Spec formula from the plan: px_dist * mm_per_px / 0.002 s → mph."""
    px_dist = math.hypot(dot2[0] - dot1[0], dot2[1] - dot1[1])
    speed_mm_s = px_dist * mm_per_px / pulse_gap_s
    return speed_mm_s * 3600.0 / (25.4 * 12.0 * 5280.0)


def spec_vla_deg(dot1, dot2) -> float:
    dx = dot2[0] - dot1[0]
    dy_up = dot1[1] - dot2[1]
    return math.degrees(math.atan2(dy_up, dx))


def test_pulse_gap_is_two_milliseconds():
    assert PULSE_GAP_S == 0.002
    assert FLASH_GAP_US == 2000
    assert FLASH_WIDTH_US == 2
    edges = dual_flash_edges_us()
    by_name = {n: t for n, t in edges}
    assert by_name["strobe2_rise"] - by_name["strobe1_rise"] == 2000
    assert by_name["strobe1_fall"] - by_name["strobe1_rise"] == 2
    assert by_name["strobe2_fall"] - by_name["strobe2_rise"] == 2


def test_metrics_from_dots_matches_spec():
    got = metrics_from_dots(DOT1, DOT2, MM_PER_PX, pulse_gap_s=0.002)
    expected_mph = spec_speed_mph(DOT1, DOT2, MM_PER_PX, 0.002)
    expected_vla = spec_vla_deg(DOT1, DOT2)
    assert got["pulse_gap_s"] == 0.002
    assert got["ball_speed_mph"] == pytest.approx(expected_mph, rel=1e-12, abs=1e-9)
    assert got["vla_deg"] == pytest.approx(expected_vla, rel=1e-12, abs=1e-9)
    assert got["ghost_px"] == pytest.approx(px_distance(DOT1, DOT2))
    assert got["ball_speed_mph"] > 1.0


def test_calibrate_mm_per_px_feeds_speed():
    mm = mm_per_px_from_known_length(100.0, 180.0)
    assert mm == pytest.approx(1.8)
    ball_mm = mm_per_px_from_golf_ball(GOLF_BALL_DIAMETER_MM / DEFAULT_MM_PER_PX)
    assert ball_mm == pytest.approx(DEFAULT_MM_PER_PX)
    got = metrics_from_dots(DOT1, DOT2, mm)
    assert got["ball_speed_mph"] == pytest.approx(spec_speed_mph(DOT1, DOT2, mm))


def test_build_shot_result_nulls_hla_spin_club():
    m = metrics_from_dots(DOT1, DOT2, MM_PER_PX)
    result = build_shot_result(
        shot_id="shot_00007",
        unix_ts=1.0,
        ok=True,
        error=None,
        ball_speed_mph=m["ball_speed_mph"],
        vla_deg=m["vla_deg"],
        carry_yd_est=m["carry_yd_est"],
        total_yd_est=m["total_yd_est"],
        confidence=0.9,
        ghost_px=m["ghost_px"],
        pulse_gap_s=m["pulse_gap_s"],
    )
    dumped = json.loads(json.dumps(result))
    for key in SHOT_FIELDS:
        assert key in dumped
    assert dumped["schema"] == SCHEMA
    for key in NULL_METRICS:
        assert dumped[key] is None
        assert dumped[key] is not 0  # noqa: E714 — missing is null, not 0
    assert dumped["pulse_gap_s"] == 0.002
    assert dumped["hla_deg"] is None
    assert dumped["spin_rpm"] is None
    assert dumped["spin_axis_deg"] is None
    assert dumped["club_speed_mph"] is None
    assert dumped["face_deg"] is None
    assert dumped["path_deg"] is None


def test_analyze_frame_finds_two_dots(tmp_path: Path):
    img = render_two_dot_image(640, 480, DOT1, DOT2)
    d1, d2, conf = find_two_dots(img)
    assert d1[0] == pytest.approx(DOT1[0], abs=1.5)
    assert d2[0] == pytest.approx(DOT2[0], abs=1.5)
    analyzed = analyze_frame(img, MM_PER_PX)
    assert analyzed["ball_speed_mph"] == pytest.approx(
        spec_speed_mph(DOT1, DOT2, MM_PER_PX), rel=0.05
    )
    assert analyzed["vla_deg"] == pytest.approx(spec_vla_deg(DOT1, DOT2), abs=1.0)
    assert 0 < conf <= 1
    png = tmp_path / "frame.png"
    from PIL import Image

    Image.fromarray(img).save(png)
    assert png.is_file()
