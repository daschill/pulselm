"""Garmin R10 OpenConnect + E6 mapping into pulselm.shot.v1."""

from __future__ import annotations

from pathlib import Path

import pytest

from r10 import from_openconnect, ingest_shot, shot_from_payload
from store import SCHEMA


SAMPLE_OPENCONNECT = {
    "DeviceID": "Garmin R10",
    "Units": "Yards",
    "ShotNumber": 7,
    "APIversion": "1",
    "BallData": {
        "Speed": 147.5,
        "SpinAxis": -13.2,
        "TotalSpin": 3250.0,
        "HLA": 2.3,
        "VLA": 14.3,
        "CarryDistance": 256.5,
    },
    "ClubData": {
        "Speed": 98.2,
        "FaceToTarget": 1.1,
        "Path": -2.4,
    },
    "ShotDataOptions": {
        "ContainsBallData": True,
        "ContainsClubData": True,
        "IsHeartBeat": False,
    },
}

SAMPLE_E6 = {
    "Type": "SetBallData",
    "BallData": {
        "BallSpeed": 65.9,
        "LaunchAngle": 12.0,
        "LaunchDirection": -3.5,
        "SpinAxis": 353.4,
        "TotalSpin": 2700.0,
    },
}


def test_openconnect_maps_r10_fields():
    m = from_openconnect(SAMPLE_OPENCONNECT)
    assert m is not None
    assert m["ball_speed_mph"] == 147.5
    assert m["vla_deg"] == 14.3
    assert m["hla_deg"] == 2.3
    assert m["spin_rpm"] == 3250.0
    assert m["club_speed_mph"] == 98.2
    assert m["face_deg"] == 1.1
    assert m["path_deg"] == -2.4
    assert m["carry_yd_est"] == 256.5


def test_heartbeat_skipped():
    payload = {
        "DeviceID": "Garmin R10",
        "ShotNumber": 0,
        "APIversion": "1",
        "ShotDataOptions": {"IsHeartBeat": True, "ContainsBallData": False},
    }
    assert shot_from_payload(payload) is None


def test_e6_ballspeed_is_mps():
    m = shot_from_payload(SAMPLE_E6)
    assert m is not None
    assert m["ball_speed_mph"] == pytest.approx(65.9 * 2.2369362920544)
    assert m["vla_deg"] == 12.0
    assert m["hla_deg"] == -3.5
    assert m["spin_axis_deg"] == pytest.approx(353.4 - 360.0)
    assert m["spin_rpm"] == 2700.0


def test_ingest_persists_shotresult(tmp_path: Path):
    result = ingest_shot(SAMPLE_OPENCONNECT, tmp_path)
    assert result is not None
    assert result["schema"] == SCHEMA
    assert result["ball_speed_mph"] == 147.5
    assert (tmp_path / result["shot_id"] / "result.json").is_file()
