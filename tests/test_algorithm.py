"""Shipped dual-strobe math: speed/VLA from two dots; HLA only from blob sizes."""

from __future__ import annotations

import math

import pytest

from store import build_shot_result
from vision import (
    GOLF_BALL_DIAMETER_MM,
    MM_S_TO_MPH,
    analyze_frame,
    estimate_carry_total_yd,
    find_two_dots,
    hla_deg_from_blob_sizes,
    metrics_from_dots,
    render_two_dot_image,
)

DOT1 = (180.0, 420.0)
DOT2 = (255.0, 395.0)
MM_PER_PX = 1.8
PULSE_GAP_S = 0.002


def test_metrics_from_dots_speed_vla_missing_hla_spin_club_are_none():
    got = metrics_from_dots(DOT1, DOT2, MM_PER_PX, pulse_gap_s=PULSE_GAP_S)
    px_dist = math.hypot(DOT2[0] - DOT1[0], DOT2[1] - DOT1[1])
    expected_mph = px_dist * MM_PER_PX / 0.002 * MM_S_TO_MPH
    dx = DOT2[0] - DOT1[0]
    dy_up = DOT1[1] - DOT2[1]
    expected_vla = math.degrees(math.atan2(dy_up, dx))
    assert got["ball_speed_mph"] == pytest.approx(expected_mph, rel=1e-12, abs=1e-9)
    assert got["vla_deg"] == pytest.approx(expected_vla, rel=1e-12, abs=1e-9)
    assert got["pulse_gap_s"] == 0.002
    assert got["ghost_px"] == pytest.approx(px_dist)
    for key in (
        "hla_deg",
        "spin_rpm",
        "spin_axis_deg",
        "club_speed_mph",
        "face_deg",
        "path_deg",
    ):
        assert key in got
        assert got[key] is None
        assert got[key] is not 0  # noqa: E714 — missing is JSON null, not 0


def test_metrics_from_dots_ignores_camera_distance_kwargs():
    got = metrics_from_dots(
        DOT1,
        DOT2,
        MM_PER_PX,
        pulse_gap_s=PULSE_GAP_S,
        camera_distance_mm=3000.0,
        diameter1_px=12.0,
        diameter2_px=12.0,
    )
    assert got["hla_deg"] is None
    assert got["spin_rpm"] is None
    assert got["club_speed_mph"] is None


def test_hla_deg_from_blob_sizes_none_without_camera_distance():
    dx = DOT2[0] - DOT1[0]
    assert (
        hla_deg_from_blob_sizes(
            12.0, 12.0, dx, MM_PER_PX, None, pulse_gap_s=0.002
        )
        is None
    )
    assert hla_deg_from_blob_sizes(12.0, 12.0, dx, MM_PER_PX, 0.0) is None
    assert hla_deg_from_blob_sizes(12.0, 12.0, dx, MM_PER_PX, -1.0) is None
    assert hla_deg_from_blob_sizes(3.0, 3.0, dx, MM_PER_PX, 3000.0) is None
    assert hla_deg_from_blob_sizes(12.0, 12.0, 0.0, MM_PER_PX, 3000.0) is None


def test_hla_subpixel_or_equal_diameters_stay_null():
    dx = DOT2[0] - DOT1[0]
    assert (
        hla_deg_from_blob_sizes(
            12.0,
            12.0,
            dx,
            MM_PER_PX,
            3000.0,
            pulse_gap_s=0.002,
        )
        is None
    )
    assert hla_deg_from_blob_sizes(12.0, 12.4, dx, MM_PER_PX, 3000.0) is None


def test_hla_measurable_diameter_delta_uses_shipped_atan2():
    dx = DOT2[0] - DOT1[0]
    hla = hla_deg_from_blob_sizes(
        20.0,
        12.0,
        dx,
        MM_PER_PX,
        3000.0,
        pulse_gap_s=0.002,
    )
    assert hla is not None
    d_cal = GOLF_BALL_DIAMETER_MM / MM_PER_PX
    z1 = 3000.0 * d_cal / 20.0
    z2 = 3000.0 * d_cal / 12.0
    expected = math.degrees(math.atan2(z2 - z1, dx * MM_PER_PX))
    assert hla == pytest.approx(expected, rel=1e-12, abs=1e-9)


def test_find_two_dots_returns_intensity_weighted_centroid_and_diameter():
    img = render_two_dot_image(640, 480, DOT1, DOT2, radius=7)
    d1, d2, conf = find_two_dots(img)[:3]
    assert d1[0] == pytest.approx(DOT1[0], abs=1.5)
    assert d2[0] == pytest.approx(DOT2[0], abs=1.5)
    assert len(d1) >= 3 and d1[2] >= 4.0
    assert len(d2) >= 3 and d2[2] >= 4.0
    assert 0 < conf <= 1


def test_analyze_frame_hla_none_without_camera_distance():
    img = render_two_dot_image(640, 480, DOT1, DOT2)
    analyzed = analyze_frame(img, MM_PER_PX, pulse_gap_s=0.002)
    assert analyzed["hla_deg"] is None
    assert analyzed["spin_rpm"] is None
    assert analyzed["club_speed_mph"] is None
    assert analyzed["hla_deg"] is not 0  # noqa: E714


def test_analyze_frame_equal_blobs_hla_null_even_with_distance():
    img = render_two_dot_image(640, 480, DOT1, DOT2, radius=7)
    analyzed = analyze_frame(
        img, MM_PER_PX, pulse_gap_s=0.002, camera_distance_mm=3000.0
    )
    assert analyzed["hla_deg"] is None
    assert analyzed["hla_deg"] is not 0  # noqa: E714
    assert analyzed["spin_rpm"] is None
    assert analyzed["face_deg"] is None
    assert analyzed["path_deg"] is None


def test_non_positive_vla_carry_is_tee_zero():
    carry, total = estimate_carry_total_yd(150.0, 0.0)
    assert carry == 0.0
    assert total == 0.0
    down, down_total = estimate_carry_total_yd(150.0, -8.0)
    assert down == 0.0
    assert down_total == 0.0
    up, up_total = estimate_carry_total_yd(150.0, 14.0)
    assert up > 0.0
    assert up_total > up


def test_build_shot_result_passes_hla_spin_club_stay_none():
    m = metrics_from_dots(DOT1, DOT2, MM_PER_PX, pulse_gap_s=0.002)
    result = build_shot_result(
        shot_id="shot_00009",
        unix_ts=1.0,
        ok=True,
        ball_speed_mph=m["ball_speed_mph"],
        vla_deg=m["vla_deg"],
        hla_deg=0.0,
        spin_rpm=3500.0,
        club_speed_mph=90.0,
        face_deg=2.0,
        path_deg=-1.0,
        ghost_px=m["ghost_px"],
        pulse_gap_s=0.002,
    )
    assert result["hla_deg"] == 0.0
    assert result["spin_rpm"] == 3500.0
    assert result["club_speed_mph"] == 90.0
    assert result["face_deg"] == 2.0
    assert result["path_deg"] == -1.0
    defaulted = build_shot_result(
        shot_id="shot_00010",
        unix_ts=1.0,
        ok=True,
        ball_speed_mph=m["ball_speed_mph"],
        vla_deg=m["vla_deg"],
        pulse_gap_s=0.002,
    )
    assert defaulted["hla_deg"] is None
    assert defaulted["hla_deg"] is not 0  # noqa: E714
