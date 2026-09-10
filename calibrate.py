"""Scale calibration: millimetres per pixel for the OV9281 side-on view."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Optional

from vision import GOLF_BALL_DIAMETER_MM

ROOT = Path(__file__).resolve().parent
CALIBRATION_PATH = ROOT / "calibration.json"
DEFAULT_MM_PER_PX = 1.8


def mm_per_px_from_known_length(px_length: float, mm_length: float) -> float:
    if px_length <= 0 or mm_length <= 0:
        raise ValueError("px_length and mm_length must be positive")
    return mm_length / px_length


def mm_per_px_from_golf_ball(
    diameter_px: float, ball_mm: float = GOLF_BALL_DIAMETER_MM
) -> float:
    return mm_per_px_from_known_length(diameter_px, ball_mm)


def load_calibration(path: Optional[Path] = None) -> dict[str, Any]:
    p = path or CALIBRATION_PATH
    if p.is_file():
        data = json.loads(p.read_text(encoding="utf-8"))
        mm = float(data.get("mm_per_px") or 0)
        if mm > 0:
            return data
    return {
        "mm_per_px": DEFAULT_MM_PER_PX,
        "method": "default",
        "sensor": "OV9281",
        "camera": "InnoMaker CAM-MIPIOV9281V2",
    }


def save_calibration(mm_per_px: float, extra: Optional[dict[str, Any]] = None,
                     path: Optional[Path] = None) -> dict[str, Any]:
    if mm_per_px <= 0:
        raise ValueError("mm_per_px must be positive")
    data: dict[str, Any] = {
        "mm_per_px": mm_per_px,
        "sensor": "OV9281",
        "camera": "InnoMaker CAM-MIPIOV9281V2",
    }
    if extra:
        data.update(extra)
    p = path or CALIBRATION_PATH
    p.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    return data


def current_mm_per_px(path: Optional[Path] = None) -> float:
    return float(load_calibration(path)["mm_per_px"])


def current_camera_distance_mm(path: Optional[Path] = None) -> Optional[float]:
    """Calibrated camera-to-ball-plane distance, or None if unset/invalid."""
    data = load_calibration(path)
    raw = data.get("camera_distance_mm")
    if raw is None:
        return None
    try:
        dist = float(raw)
    except (TypeError, ValueError):
        return None
    if dist <= 0:
        return None
    return dist
