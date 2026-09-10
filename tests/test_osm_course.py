"""OSM hole maps: synthetic fallback + real fairway rings from injected Overpass."""

from __future__ import annotations

from osm_course import build_hole_map, synthetic_hole


def test_synthetic_has_fairway_green_trees():
    h = synthetic_hole(4, 380)
    assert h["fairways"]
    assert h["greens"]
    assert h["trees"]
    assert h["bunkers"]
    assert h["hole_line"][-1][1] == 380


def test_build_map_from_osm_hole_and_fairway():
    els = [
        {
            "type": "way",
            "tags": {"golf": "hole", "ref": "1"},
            "geometry": [
                {"lat": 40.0, "lon": -73.0},
                {"lat": 40.002, "lon": -73.0},
            ],
        },
        {
            "type": "way",
            "tags": {"golf": "fairway"},
            "geometry": [
                {"lat": 40.0005, "lon": -73.0004},
                {"lat": 40.0015, "lon": -73.0004},
                {"lat": 40.0015, "lon": -72.9996},
                {"lat": 40.0005, "lon": -72.9996},
                {"lat": 40.0005, "lon": -73.0004},
            ],
        },
        {
            "type": "node",
            "lat": 40.001,
            "lon": -73.0008,
            "tags": {"natural": "tree"},
        },
    ]
    m = build_hole_map(els, hole_num=1, par=4, pin_yd=220)
    assert m["source"] == "osm"
    assert m["fairways"]
    assert m["trees"]
    # green is downrange of tee
    assert m["hole_line"][-1][1] > 50
