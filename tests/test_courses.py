"""OpenGolfAPI course mapping uses injected fetch — no live network in the gate."""

from __future__ import annotations

from courses import course_with_holes, holes_as_targets, pin_yards_from_hole, search_courses


def test_search_normalizes_rows():
    def fetch(url: str):
        assert "search" in url
        return {
            "courses": [
                {
                    "id": "abc",
                    "name": "Bethpage Black",
                    "city": "Farmingdale",
                    "state": "NY",
                    "type": "Municipal",
                    "par": 71,
                }
            ],
            "total": 1,
            "_license": "ODbL-1.0",
            "_attribution": "test",
        }

    out = search_courses("bethpage", fetch=fetch)
    assert out["ok"] is True
    assert out["courses"][0]["name"] == "Bethpage Black"
    assert out["license"] == "ODbL-1.0"


def test_hole_pin_prefers_blue_tees():
    hole = {"number": 7, "par": 3, "yardages": {"red": 90, "white": 110, "blue": 120}}
    assert pin_yards_from_hole(hole) == 120
    targets = holes_as_targets({"holes": [hole]})
    assert targets[0] == {"hole": 7, "par": 3, "pin_yd": 120}
    assert len(targets) == 18


def test_course_with_holes_uses_scorecard_fallback():
    def fetch(url: str):
        if url.endswith("/holes"):
            return {"holes": []}
        return {
            "id": "xyz",
            "name": "Demo Muni",
            "city": "X",
            "state": "CA",
            "type": "Municipal",
            "par": 72,
            "scorecard": [{"hole": 1, "par": 4}, {"hole": 2, "par": 3}],
            "_license": "ODbL-1.0",
        }

    out = course_with_holes("xyz", fetch=fetch)
    assert out["name"] == "Demo Muni"
    assert [h["hole"] for h in out["holes"][:2]] == [1, 2]
    assert out["holes"][1]["par"] == 3
    assert len(out["holes"]) == 18
