"""4-cam + 24 GHz radar fusion. Dual-strobe-only still leaves spin/club null."""

from __future__ import annotations

import math

import pytest

from cameras import hla_deg_from_stereo_ghosts, spin_rpm_from_mark
from fusion import fuse_shot
from radar import doppler_hz_for_speed_mps, speed_mph_from_doppler
from vision import metrics_from_dots

DOT1 = (180.0, 420.0)
DOT2 = (255.0, 395.0)
MM = 1.8


def test_doppler_roundtrip_150_mph():
    mps = 150.0 / 2.2369362920544
    fd = doppler_hz_for_speed_mps(mps)
    assert speed_mph_from_doppler(fd) == pytest.approx(150.0, rel=1e-9)


def test_fusion_prefers_radar_ball_speed():
    fd = doppler_hz_for_speed_mps(67.056)
    fused = fuse_shot(
        side_dot1=DOT1,
        side_dot2=DOT2,
        mm_per_px=MM,
        radar_ball_doppler_hz=fd,
        radar_club_doppler_hz=doppler_hz_for_speed_mps(67.056 / 1.45),
    )
    vis = metrics_from_dots(DOT1, DOT2, MM)
    assert fused["ball_speed_mph"] == pytest.approx(speed_mph_from_doppler(fd))
    assert fused["ball_speed_mph"] != pytest.approx(vis["ball_speed_mph"])
    assert fused["sources"]["ball_speed_mph"] == "radar"
    assert fused["club_speed_mph"] is not None
    assert fused["vla_deg"] == pytest.approx(vis["vla_deg"])
    assert fused["spin_rpm"] is None


def test_dual_strobe_only_club_spin_null():
    fused = fuse_shot(side_dot1=DOT1, side_dot2=DOT2, mm_per_px=MM)
    assert fused["ball_speed_mph"] is not None
    assert fused["sources"]["ball_speed_mph"] == "dual_strobe"
    assert fused["hla_deg"] is None
    assert fused["spin_rpm"] is None
    assert fused["club_speed_mph"] is None
    assert fused["face_deg"] is None
    assert fused["path_deg"] is None


def test_stereo_hla_from_constructed_disparity():
    hla = hla_deg_from_stereo_ghosts(
        (200.0, 400.0),
        (280.0, 390.0),
        (160.0, 400.0),
        (236.0, 390.0),
        baseline_mm=80.0,
        focal_px=800.0,
        mm_per_px_left=1.8,
    )
    assert hla is not None
    z1 = 80.0 * 800.0 / 40.0
    z2 = 80.0 * 800.0 / 44.0
    expect = math.degrees(math.atan2(z2 - z1, 80.0 * 1.8))
    assert hla == pytest.approx(expect)


def test_spin_from_mark_20_deg_in_2ms():
    rpm = spin_rpm_from_mark(0.0, 20.0, 0.002)
    assert rpm == pytest.approx(20.0 / 360.0 / 0.002 * 60.0)
    fused = fuse_shot(
        side_dot1=DOT1,
        side_dot2=DOT2,
        mm_per_px=MM,
        mark_angle1_deg=0.0,
        mark_angle2_deg=20.0,
    )
    assert fused["spin_rpm"] == pytest.approx(rpm)
    assert fused["sources"]["spin_rpm"] == "ball_mark"


def test_face_on_hla_and_club_path():
    fused = fuse_shot(
        side_dot1=DOT1,
        side_dot2=DOT2,
        mm_per_px=MM,
        face_on_dot1=(320.0, 400.0),
        face_on_dot2=(340.0, 300.0),
        club_dot1=(200.0, 500.0),
        club_dot2=(260.0, 480.0),
    )
    assert fused["hla_deg"] is not None
    assert fused["path_deg"] is not None
    assert fused["spin_rpm"] is None
