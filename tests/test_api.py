"""Drive the shipped Flask app in --demo (no GPIO)."""

from __future__ import annotations

from pathlib import Path

import pytest

from api import HOST, PORT, create_app
from store import SCHEMA, SHOT_FIELDS, load_fixture_result


@pytest.fixture()
def client(tmp_path: Path):
    app = create_app(
        demo=True,
        shots_dir=tmp_path,
        calibration_path=tmp_path / "calibration.json",
    )
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def test_demo_range_landing_from_shot(client):
    r = client.get("/api/v1/range")
    assert r.status_code == 200
    land = r.get_json()
    fixture = load_fixture_result()
    assert land["along_yd"] == pytest.approx(float(fixture["carry_yd_est"]))
    assert land["offline_yd"] == 0.0
    assert land["on_line"] is True


def test_demo_session_and_csv(client):
    s = client.get("/api/v1/session")
    assert s.status_code == 200
    body = s.get_json()
    assert body["ok"] is True
    assert body["shot_count"] >= 1
    assert body["ball_speed_mph_mean"] == pytest.approx(159.1608)
    assert "spin_rpm" in body["not_measured"]
    csv = client.get("/shots.csv")
    assert csv.status_code == 200
    text = csv.get_data(as_text=True)
    assert "ball_speed_mph" in text.splitlines()[0]
    assert "159.1608" in text


def test_demo_health_and_latest(client):
    h = client.get("/api/v1/health")
    assert h.status_code == 200
    body = h.get_json()
    assert body["ok"] is True
    assert body["demo"] is True
    assert body["gpio"] is None
    latest = client.get("/shot/latest")
    assert latest.status_code == 200
    shot = latest.get_json()
    assert shot["schema"] == SCHEMA
    assert shot["pulse_gap_s"] == 0.002
    assert isinstance(shot["ball_speed_mph"], (int, float))
    assert shot["ball_speed_mph"] > 1
    assert shot["hla_deg"] is None
    fixture = load_fixture_result()
    assert shot["ball_speed_mph"] == fixture["ball_speed_mph"]
    assert list(shot.keys()) == list(SHOT_FIELDS)


def test_demo_index_shows_speed(client):
    fixture = load_fixture_result()
    speed = f"{float(fixture['ball_speed_mph']):.2f}"
    page = client.get("/")
    assert page.status_code == 200
    html = page.get_data(as_text=True)
    assert speed in html
    assert "Ball speed" in html
    assert "PulseLM" in html
    assert 'id="hla"' in html
    assert 'id="spin"' in html
    assert 'id="club"' in html
    assert fixture["hla_deg"] is None
    assert fixture["spin_rpm"] is None
    assert ">HLA<" in html or "HLA</span>" in html


def test_demo_arm_calibrate_shots(client):
    armed = client.post("/arm")
    assert armed.status_code == 200
    shot = armed.get_json()
    assert shot["ok"] is True
    assert shot["shot_id"].startswith("shot_")
    listed = client.get("/shots")
    assert listed.status_code == 200
    data = listed.get_json()
    assert data["count"] >= 2
    one = client.get(f"/shot/{shot['shot_id']}")
    assert one.status_code == 200
    png = client.get(f"/shot/{shot['shot_id']}/raw.png")
    assert png.status_code == 200
    assert png.mimetype == "image/png"
    cal = client.post("/calibrate", json={"mm_per_px": 1.8})
    assert cal.status_code == 200
    assert cal.get_json()["ok"] is True


def test_bind_host_port_and_cors(client):
    assert HOST == "0.0.0.0"
    assert PORT == 8080
    h = client.get("/api/v1/health")
    assert h.headers.get("Access-Control-Allow-Origin") == "*"
    pre = client.options(
        "/api/v1/health",
        headers={
            "Origin": "http://iphone.local",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert pre.status_code in (200, 204)
    assert pre.headers.get("Access-Control-Allow-Origin") in ("*", "http://iphone.local")


def test_missing_shot_is_shotresult_404(client):
    missing = client.get("/shot/shot_99999")
    assert missing.status_code == 404
    body = missing.get_json()
    assert body["ok"] is False
    assert body["schema"] == SCHEMA
    assert body["error"] == "not found"
    for key in SHOT_FIELDS:
        assert key in body
    assert body["hla_deg"] is None
    png = client.get("/shot/shot_99999/raw.png")
    assert png.status_code == 404


def test_demo_never_imports_gpio():
    import sys

    assert "RPi" not in sys.modules
    assert "RPi.GPIO" not in sys.modules
    assert "picamera2" not in sys.modules


def test_calibrate_known_length_and_golf_ball(client):
    known = client.post("/calibrate", json={"px_length": 100, "mm_length": 180})
    assert known.status_code == 200
    body = known.get_json()
    assert body["ok"] is True
    assert body["calibration"]["mm_per_px"] == pytest.approx(1.8)
    ball = client.post("/calibrate", json={"diameter_px": 42.67 / 1.8})
    assert ball.status_code == 200
    assert ball.get_json()["ok"] is True
    dist = client.post(
        "/calibrate", json={"mm_per_px": 1.8, "camera_distance_mm": 3000}
    )
    assert dist.status_code == 200
    cal = dist.get_json()["calibration"]
    assert cal["mm_per_px"] == pytest.approx(1.8)
    assert cal["camera_distance_mm"] == pytest.approx(3000.0)
    keep = client.post("/calibrate", json={"mm_per_px": 1.9})
    assert keep.get_json()["calibration"]["camera_distance_mm"] == pytest.approx(3000.0)
    bad = client.post("/calibrate", json={"mm_per_px": 0})
    assert bad.status_code == 400
    assert bad.get_json()["ok"] is False


def test_empty_shots_latest_is_shotresult_404(tmp_path: Path):
    app = create_app(
        demo=False,
        shots_dir=tmp_path,
        calibration_path=tmp_path / "calibration.json",
    )
    app.config["TESTING"] = True
    with app.test_client() as c:
        r = c.get("/shot/latest")
    assert r.status_code == 404
    body = r.get_json()
    assert body["ok"] is False
    assert body["schema"] == SCHEMA
    assert body["error"] == "no shots"
    assert body["hla_deg"] is None


def test_live_arm_without_pi_libs_is_error_shotresult(tmp_path: Path):
    app = create_app(
        demo=False,
        shots_dir=tmp_path,
        calibration_path=tmp_path / "calibration.json",
    )
    app.config["TESTING"] = True
    with app.test_client() as c:
        r = c.post("/arm")
    assert r.status_code == 200
    body = r.get_json()
    assert body["ok"] is False
    assert body["schema"] == SCHEMA
    assert body["error"]
    assert body["hla_deg"] is None
    assert body["pulse_gap_s"] == 0.002
