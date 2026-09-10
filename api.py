"""Flask HTTP API. Bind 0.0.0.0:8080 with CORS. --demo never touches GPIO."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Optional

from flask import Flask, Response, jsonify, request, send_file
from flask_cors import CORS

import calibrate
import range_landing
import shot_ui
import store
from service.pulse import PULSE_GAP_S, STROBE_PIN, TRIG_PIN
from vision import analyze_frame, metrics_from_dots

ROOT = Path(__file__).resolve().parent
WEB_DIR = ROOT / "web"
HOST = "0.0.0.0"
PORT = 8080


def create_app(
    *,
    demo: bool = False,
    shots_dir: Optional[Path] = None,
    calibration_path: Optional[Path] = None,
) -> Flask:
    app = Flask(__name__)
    CORS(app, resources={r"/*": {"origins": "*"}})
    # Keep ShotResult field order from store.build_shot_result (not alpha-sorted).
    try:
        app.json.sort_keys = False
    except Exception:
        app.config["JSON_SORT_KEYS"] = False
    app.config["PULSELM_DEMO"] = bool(demo)
    app.config["PULSELM_SHOTS"] = Path(shots_dir) if shots_dir else store.SHOTS_DIR
    app.config["PULSELM_CAL"] = (
        Path(calibration_path) if calibration_path else calibrate.CALIBRATION_PATH
    )

    if demo:
        store.seed_demo_shot(app.config["PULSELM_SHOTS"])

    def shots_root() -> Path:
        return app.config["PULSELM_SHOTS"]

    @app.get("/api/v1/health")
    def health() -> Any:
        return jsonify(
            {
                "ok": True,
                "service": "pulselm",
                "demo": bool(app.config["PULSELM_DEMO"]),
                "gpio": None if app.config["PULSELM_DEMO"] else {
                    "strobe": STROBE_PIN,
                    "trig": TRIG_PIN,
                },
                "pulse_gap_s": PULSE_GAP_S,
                "schema": store.SCHEMA,
            }
        )

    @app.get("/api/v1/range")
    def range_view() -> Any:
        result = store.latest_result(shots_root())
        if result is None:
            return jsonify(
                store.build_shot_result(
                    shot_id="shot_00000",
                    unix_ts=0,
                    ok=False,
                    error="no shots",
                    pulse_gap_s=PULSE_GAP_S,
                )
            ), 404
        payload = range_landing.landing_from_shot(result)
        payload["shot_id"] = result.get("shot_id")
        return jsonify(payload)

    @app.get("/shot/latest")
    def shot_latest() -> Any:
        result = store.latest_result(shots_root())
        if result is None:
            return jsonify(
                store.build_shot_result(
                    shot_id="shot_00000",
                    unix_ts=0,
                    ok=False,
                    error="no shots",
                    pulse_gap_s=PULSE_GAP_S,
                )
            ), 404
        return jsonify(result)

    @app.get("/shot/<shot_id>")
    def shot_by_id(shot_id: str) -> Any:
        try:
            return jsonify(store.load_result(shot_id, shots_root()))
        except FileNotFoundError:
            return jsonify(
                store.build_shot_result(
                    shot_id=shot_id,
                    unix_ts=0,
                    ok=False,
                    error="not found",
                    pulse_gap_s=PULSE_GAP_S,
                )
            ), 404

    @app.get("/shots")
    def shots() -> Any:
        ids = store.list_shot_ids(shots_root())
        items = []
        for sid in ids:
            try:
                items.append(store.load_result(sid, shots_root()))
            except FileNotFoundError:
                continue
        return jsonify({"ok": True, "count": len(items), "shots": items})

    @app.get("/shot/<shot_id>/raw.png")
    def shot_raw(shot_id: str) -> Any:
        try:
            path = store.raw_png_path(shot_id, shots_root())
        except FileNotFoundError:
            return jsonify(
                store.build_shot_result(
                    shot_id=shot_id,
                    unix_ts=0,
                    ok=False,
                    error="not found",
                    pulse_gap_s=PULSE_GAP_S,
                )
            ), 404
        return send_file(path, mimetype="image/png")

    @app.post("/arm")
    def arm() -> Any:
        if app.config["PULSELM_DEMO"]:
            result = store.record_demo_shot(shots_root())
            return jsonify(result)
        return jsonify(_live_capture(shots_root(), app.config["PULSELM_CAL"]))

    @app.post("/calibrate")
    def do_calibrate() -> Any:
        body = request.get_json(silent=True) or {}
        if "mm_per_px" in body:
            mm = float(body["mm_per_px"])
            extra = {"method": "direct"}
        elif "px_length" in body and "mm_length" in body:
            mm = calibrate.mm_per_px_from_known_length(
                float(body["px_length"]), float(body["mm_length"])
            )
            extra = {
                "method": "known_length",
                "px_length": float(body["px_length"]),
                "mm_length": float(body["mm_length"]),
            }
        elif "diameter_px" in body:
            mm = calibrate.mm_per_px_from_golf_ball(float(body["diameter_px"]))
            extra = {"method": "golf_ball", "diameter_px": float(body["diameter_px"])}
        else:
            mm = calibrate.current_mm_per_px(app.config["PULSELM_CAL"])
            extra = {"method": "unchanged"}
        try:
            saved = calibrate.save_calibration(mm, extra, path=app.config["PULSELM_CAL"])
        except ValueError as exc:
            return jsonify({"ok": False, "error": str(exc)}), 400
        return jsonify({"ok": True, "calibration": saved})

    @app.get("/")
    def index() -> Any:
        html = (WEB_DIR / "index.html").read_text(encoding="utf-8")
        latest = store.latest_result(shots_root())
        speed = ""
        vla = ""
        carry = ""
        sid = ""
        along = ""
        offline = "0"
        if latest and latest.get("ball_speed_mph") is not None:
            hud = shot_ui.hud_from_shot(latest)
            speed = hud["speed_string"]
            vla = hud["vla_string"]
            carry = hud["carry_string"]
            sid = latest.get("shot_id") or ""
            land = hud["landing"]
            if land.get("along_yd") is not None:
                along = f"{float(land['along_yd']):.1f}"
            if land.get("offline_yd") is not None:
                offline = f"{float(land['offline_yd']):.1f}"
        html = (
            html.replace("{{BALL_SPEED_MPH}}", speed or "—")
            .replace("{{VLA_DEG}}", vla or "—")
            .replace("{{CARRY_YD}}", carry or "—")
            .replace("{{SHOT_ID}}", sid)
            .replace("{{ALONG_YD}}", along or "—")
            .replace("{{OFFLINE_YD}}", offline)
            .replace("{{DEMO}}", "true" if app.config["PULSELM_DEMO"] else "false")
        )
        return Response(html, mimetype="text/html")

    return app


def _live_capture(shots_root: Path, cal_path: Optional[Path] = None) -> dict[str, Any]:
    import time

    sid = store.next_shot_id(shots_root)
    now = time.time()
    try:
        from service.pulse import capture_dual_strobe_frame

        mm = calibrate.current_mm_per_px(cal_path)
        frame = capture_dual_strobe_frame()
        analyzed = analyze_frame(frame, mm_per_px=mm, pulse_gap_s=PULSE_GAP_S)
    except Exception as exc:
        return store.build_shot_result(
            shot_id=sid,
            unix_ts=now,
            ok=False,
            error=str(exc),
            pulse_gap_s=PULSE_GAP_S,
        )

    result = store.build_shot_result(
        shot_id=sid,
        unix_ts=now,
        ok=True,
        error=None,
        ball_speed_mph=analyzed["ball_speed_mph"],
        vla_deg=analyzed["vla_deg"],
        hla_deg=analyzed.get("hla_deg"),
        carry_yd_est=analyzed["carry_yd_est"],
        total_yd_est=analyzed["total_yd_est"],
        confidence=analyzed["confidence"],
        ghost_px=analyzed["ghost_px"],
        pulse_gap_s=PULSE_GAP_S,
    )
    store.save_shot(
        result=result,
        raw_image=frame,
        meta={
            "demo": False,
            "mm_per_px": mm,
            "dot1": analyzed["dot1"],
            "dot2": analyzed["dot2"],
            "strobe_pin": STROBE_PIN,
            "trig_pin": TRIG_PIN,
        },
        shots_dir=shots_root,
    )
    return result


# Re-export for tests that want the math through the API module surface.
__all__ = ["create_app", "HOST", "PORT", "metrics_from_dots"]
