"""Gating: shipped JSON→HUD/range mapping + native iOS sources bind field names."""

from __future__ import annotations

from pathlib import Path

from shot_ui import hud_from_shot
from store import load_fixture_result

ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "PulseLM"


def test_hud_speed_string_from_fixture():
    fixture = load_fixture_result()
    assert fixture["ball_speed_mph"] == 159.1608
    hud = hud_from_shot(fixture)
    assert hud["speed_string"] == "159.16"
    assert hud["landing"]["along_yd"] == fixture["carry_yd_est"]
    assert hud["landing"]["offline_yd"] == 0.0
    assert hud["hla_string"] == "—"
    assert hud["spin_string"] == "—"
    assert hud["club_string"] == "—"


def test_ios_sources_bind_shotresult_fields():
    required = [
        IOS_ROOT / "PulseLM" / "PulseLMApp.swift",
        IOS_ROOT / "PulseLM" / "ContentView.swift",
        IOS_ROOT / "PulseLM" / "Models" / "ShotResult.swift",
        IOS_ROOT / "PulseLM" / "Mapping" / "ShotMapping.swift",
        IOS_ROOT / "PulseLM" / "Mapping" / "RangeLanding.swift",
        IOS_ROOT / "PulseLM" / "Views" / "RangeView.swift",
        IOS_ROOT / "PulseLM" / "Views" / "ShotHUD.swift",
        IOS_ROOT / "PulseLM.xcodeproj" / "project.pbxproj",
    ]
    missing = [str(p) for p in required if not p.is_file()]
    assert not missing, f"iOS sources missing: {missing}"
    blob = "\n".join(p.read_text(encoding="utf-8") for p in required if p.is_file())
    for key in (
        "ball_speed_mph",
        "vla_deg",
        "hla_deg",
        "carry_yd_est",
        "pulse_gap_s",
        "spin_rpm",
        "club_speed_mph",
    ):
        assert key in blob, f"iOS client missing ShotResult key {key}"
    assert "159.16" in (IOS_ROOT / "PulseLM" / "Mapping" / "ShotMapping.swift").read_text(
        encoding="utf-8"
    ) or "%.2f" in blob
    landing_src = (IOS_ROOT / "PulseLM" / "Mapping" / "RangeLanding.swift").read_text(
        encoding="utf-8"
    )
    assert "cos(" in landing_src and "sin(" in landing_src
    assert "hla == nil" in landing_src or "hla == nil" in blob
    assert "AVCapture" not in blob
    assert "CBCentralManager" not in blob
    range_src = (IOS_ROOT / "PulseLM" / "Views" / "RangeView.swift").read_text(
        encoding="utf-8"
    )
    assert "RangeLanding.from" in range_src
    assert "yd off" in range_src
    assert "ShotTracer" in range_src
    assert "session" in range_src
    assert "pinYards" in range_src
    assert "150.0, 200.0, 250.0, 300.0, 400.0, 500.0" in range_src
    assert "maxAlongYd: Double = 500" in range_src
    assert "closest" in range_src
    assert "longest" in range_src
    assert "Smash" in range_src
    assert "dispersionRings" in range_src
