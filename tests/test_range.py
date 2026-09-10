"""Gating: shipped range-landing transform on ShotResult payloads."""

from __future__ import annotations

import json
import math
from pathlib import Path

import pytest

from range_landing import landing_from_shot, landing_yd
from store import load_fixture_result

ROOT = Path(__file__).resolve().parents[1]


def test_null_hla_lands_on_target_line():
    fixture = load_fixture_result()
    assert fixture["hla_deg"] is None
    land = landing_from_shot(fixture)
    assert land["on_line"] is True
    assert land["offline_yd"] == 0.0
    assert land["along_yd"] == pytest.approx(float(fixture["carry_yd_est"]))
    same = landing_yd(fixture["carry_yd_est"], None)
    assert same["along_yd"] == land["along_yd"]
    assert same["offline_yd"] == land["offline_yd"]


def test_hla_rotates_carry_with_shipped_cos_sin():
    carry = 200.0
    hla = 12.0
    land = landing_yd(carry, hla)
    rad = math.radians(hla)
    assert land["along_yd"] == pytest.approx(carry * math.cos(rad))
    assert land["offline_yd"] == pytest.approx(carry * math.sin(rad))
    assert land["on_line"] is False
    shot = {
        "shot_id": "shot_00009",
        "carry_yd_est": carry,
        "hla_deg": hla,
        "ball_speed_mph": 140.0,
    }
    from_shot = landing_from_shot(shot)
    assert from_shot["along_yd"] == land["along_yd"]
    assert from_shot["offline_yd"] == land["offline_yd"]


def test_missing_carry_is_null_not_zero():
    land = landing_yd(None, None)
    assert land["along_yd"] is None
    assert land["offline_yd"] is None
    assert land["on_line"] is True
    dumped = json.dumps(land)
    assert "null" in dumped
    with_hla = landing_yd(None, 6.0)
    assert with_hla["along_yd"] is None
    assert with_hla["offline_yd"] is None
    assert with_hla["on_line"] is False
