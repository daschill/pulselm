"""Gating tests: ShotResult schema on fixture + produced result.json."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from store import (
    FIXTURES_DIR,
    NULL_METRICS,
    SCHEMA,
    SHOT_FIELDS,
    build_shot_result,
    load_fixture_result,
    save_shot,
)
from vision import metrics_from_dots, render_two_dot_image

ROOT = Path(__file__).resolve().parents[1]


def _assert_shot_schema(data: dict) -> None:
    assert data["schema"] == SCHEMA == "pulselm.shot.v1"
    for key in SHOT_FIELDS:
        assert key in data, f"missing field {key}"
    assert list(data.keys()) == list(SHOT_FIELDS)
    assert data["pulse_gap_s"] == 0.002
    for key in NULL_METRICS:
        assert key in data
        assert data[key] is None, f"{key} must be JSON null, not {data[key]!r}"
    # Field names must not be renamed aliases.
    assert "ballSpeedMph" not in data
    assert "ball_speed" not in data
    assert "launch_angle" not in data


def test_fixture_png_matches_sample_result_math():
    from PIL import Image
    import numpy as np
    from vision import analyze_frame

    raw = json.loads((FIXTURES_DIR / "sample_result.json").read_text(encoding="utf-8"))
    img = np.asarray(Image.open(FIXTURES_DIR / "sample_raw.png"))
    analyzed = analyze_frame(img, mm_per_px=1.8, pulse_gap_s=0.002)
    assert analyzed["ball_speed_mph"] == pytest.approx(raw["ball_speed_mph"], rel=1e-4)
    assert analyzed["vla_deg"] == pytest.approx(raw["vla_deg"], rel=1e-4)
    assert analyzed["ghost_px"] == pytest.approx(raw["ghost_px"], rel=1e-4)
    assert analyzed["pulse_gap_s"] == raw["pulse_gap_s"] == 0.002


def test_fixture_sample_result_schema():
    path = FIXTURES_DIR / "sample_result.json"
    assert path.is_file()
    raw = json.loads(path.read_text(encoding="utf-8"))
    _assert_shot_schema(raw)
    assert raw["ok"] is True
    assert raw["error"] is None
    assert isinstance(raw["ball_speed_mph"], (int, float))
    assert raw["ball_speed_mph"] != 0
    loaded = load_fixture_result()
    _assert_shot_schema(loaded)
    assert loaded["ball_speed_mph"] == raw["ball_speed_mph"]


def test_produced_result_json_schema(tmp_path: Path):
    m = metrics_from_dots((180.0, 420.0), (255.0, 395.0), 1.8)
    result = build_shot_result(
        shot_id="shot_00002",
        unix_ts=1700000000.0,
        ok=True,
        error=None,
        ball_speed_mph=m["ball_speed_mph"],
        vla_deg=m["vla_deg"],
        carry_yd_est=m["carry_yd_est"],
        total_yd_est=m["total_yd_est"],
        confidence=0.91,
        ghost_px=m["ghost_px"],
        pulse_gap_s=0.002,
    )
    img = render_two_dot_image(320, 240, (40, 180), (90, 160), radius=5)
    dest = save_shot(result=result, raw_image=img, meta={"demo": True}, shots_dir=tmp_path)
    assert dest.name == "shot_00002"
    assert (dest / "raw.png").is_file()
    assert (dest / "meta.json").is_file()
    produced = json.loads((dest / "result.json").read_text(encoding="utf-8"))
    _assert_shot_schema(produced)
    dumped = json.dumps(produced)
    assert "null" in dumped
    for key in NULL_METRICS:
        # Ensure the file actually contains JSON null for that key, not 0.
        assert f'"{key}": null' in dumped.replace(" ", "") or (
            produced[key] is None
        )
