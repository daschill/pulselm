"""On-course play: remaining yards shrink by carry; gimme inside 3 yd."""

from __future__ import annotations

from pathlib import Path

from play import apply_shot, public_view, start_round
from store import build_shot_result


def _fake_fetch(url: str) -> dict:
    if url.endswith("/holes"):
        return {
            "holes": [
                {"number": 1, "par": 4, "yardages": {"blue": 360}},
                {"number": 2, "par": 3, "yardages": {"blue": 150}},
            ]
        }
    return {
        "id": "course-1",
        "name": "Test Muni",
        "city": "X",
        "state": "NY",
        "par": 71,
        "scorecard": [],
        "_license": "ODbL-1.0",
        "_attribution": "test",
    }


def test_round_advances_and_holes_out(tmp_path: Path):
    ten = start_round("course-1", tmp_path, fetch=_fake_fetch, max_holes=10)
    assert len(ten["holes"]) == 10
    eighteen = start_round("course-1", tmp_path, fetch=_fake_fetch, max_holes=18)
    assert len(eighteen["holes"]) == 18
    doc = start_round("course-1", tmp_path, fetch=_fake_fetch)
    assert doc["current"]["pin_yd"] == 360
    view = public_view(doc)
    assert view["course_name"] == "Test Muni"
    assert view["remaining_yd"] == 360

    shot1 = build_shot_result(
        shot_id="shot_00001",
        unix_ts=1.0,
        ok=True,
        ball_speed_mph=150.0,
        vla_deg=12.0,
        carry_yd_est=240.0,
    )
    doc = apply_shot(shot1, tmp_path)
    assert doc is not None
    assert doc["current"]["strokes"] == 1
    assert doc["current"]["remaining_yd"] == 120.0

    shot2 = build_shot_result(
        shot_id="shot_00002",
        unix_ts=2.0,
        ok=True,
        ball_speed_mph=90.0,
        vla_deg=20.0,
        carry_yd_est=118.0,
    )
    doc = apply_shot(shot2, tmp_path)
    # leftover 2 yd → gimme putt, hole complete, move to hole 2
    assert doc["thru"] == 1
    assert doc["scorecard"][0]["strokes"] == 3
    assert doc["current"]["hole"] == 2
    assert doc["current"]["pin_yd"] == 150
