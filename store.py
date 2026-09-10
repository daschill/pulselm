"""Shot persistence and ShotResult serialization (pulselm.shot.v1)."""

from __future__ import annotations

import json
import re
import shutil
import time
from pathlib import Path
from typing import Any, Optional

from PIL import Image
import numpy as np

from service.pulse import PULSE_GAP_S

ROOT = Path(__file__).resolve().parent
SHOTS_DIR = ROOT / "shots"
FIXTURES_DIR = ROOT / "fixtures"
SCHEMA = "pulselm.shot.v1"
SHOT_ID_RE = re.compile(r"^shot_(\d{5})$")

# Field names are part of the Week-1 contract. Do not rename.
SHOT_FIELDS = (
    "schema",
    "shot_id",
    "unix_ts",
    "ok",
    "error",
    "ball_speed_mph",
    "vla_deg",
    "hla_deg",
    "spin_rpm",
    "spin_axis_deg",
    "club_speed_mph",
    "face_deg",
    "path_deg",
    "carry_yd_est",
    "total_yd_est",
    "confidence",
    "ghost_px",
    "pulse_gap_s",
)

NULL_METRICS = (
    "hla_deg",
    "spin_rpm",
    "spin_axis_deg",
    "club_speed_mph",
    "face_deg",
    "path_deg",
)


def _null() -> None:
    return None


def build_shot_result(
    *,
    shot_id: str,
    unix_ts: float,
    ok: bool,
    error: Optional[str] = None,
    ball_speed_mph: Optional[float] = None,
    vla_deg: Optional[float] = None,
    carry_yd_est: Optional[float] = None,
    total_yd_est: Optional[float] = None,
    confidence: Optional[float] = None,
    ghost_px: Optional[float] = None,
    pulse_gap_s: float = PULSE_GAP_S,
    **_ignored: Any,
) -> dict[str, Any]:
    """Assemble a ShotResult. Missing metrics are JSON null, never 0-as-missing."""
    result: dict[str, Any] = {
        "schema": SCHEMA,
        "shot_id": shot_id,
        "unix_ts": unix_ts,
        "ok": bool(ok),
        "error": error,
        "ball_speed_mph": ball_speed_mph,
        "vla_deg": vla_deg,
        "hla_deg": _null(),
        "spin_rpm": _null(),
        "spin_axis_deg": _null(),
        "club_speed_mph": _null(),
        "face_deg": _null(),
        "path_deg": _null(),
        "carry_yd_est": carry_yd_est,
        "total_yd_est": total_yd_est,
        "confidence": confidence,
        "ghost_px": ghost_px,
        "pulse_gap_s": pulse_gap_s,
    }
    return {k: result[k] for k in SHOT_FIELDS}


def shot_dir(shot_id: str, shots_dir: Optional[Path] = None) -> Path:
    return (shots_dir or SHOTS_DIR) / shot_id


def parse_shot_index(shot_id: str) -> int:
    m = SHOT_ID_RE.match(shot_id)
    if not m:
        raise ValueError(f"invalid shot_id: {shot_id}")
    return int(m.group(1))


def format_shot_id(index: int) -> str:
    if index < 1 or index > 99999:
        raise ValueError("shot index out of range")
    return f"shot_{index:05d}"


def list_shot_ids(shots_dir: Optional[Path] = None) -> list[str]:
    root = shots_dir or SHOTS_DIR
    if not root.is_dir():
        return []
    ids = []
    for p in root.iterdir():
        if p.is_dir() and SHOT_ID_RE.match(p.name) and (p / "result.json").is_file():
            ids.append(p.name)
    ids.sort()
    return ids


def next_shot_id(shots_dir: Optional[Path] = None) -> str:
    ids = list_shot_ids(shots_dir)
    if not ids:
        return format_shot_id(1)
    return format_shot_id(parse_shot_index(ids[-1]) + 1)


def _write_png(path: Path, image: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(image, (str, Path)):
        src = Path(image)
        if src.resolve() != path.resolve():
            shutil.copyfile(src, path)
        return
    arr = np.asarray(image)
    if arr.ndim == 2:
        mode = "L"
    else:
        mode = "RGB"
        if arr.shape[2] == 4:
            mode = "RGBA"
    Image.fromarray(arr, mode=mode).save(path, format="PNG")


def save_shot(
    *,
    result: dict[str, Any],
    raw_image: Any,
    meta: Optional[dict[str, Any]] = None,
    shots_dir: Optional[Path] = None,
) -> Path:
    """Write shots/shot_NNNNN/{raw.png, meta.json, result.json}."""
    shot_id = result["shot_id"]
    dest = shot_dir(shot_id, shots_dir)
    dest.mkdir(parents=True, exist_ok=True)
    raw_path = dest / "raw.png"
    _write_png(raw_path, raw_image)
    ordered = build_shot_result(**result)
    (dest / "result.json").write_text(
        json.dumps(ordered, indent=2) + "\n", encoding="utf-8"
    )
    payload = dict(meta or {})
    payload.setdefault("shot_id", shot_id)
    payload.setdefault("schema", SCHEMA)
    (dest / "meta.json").write_text(
        json.dumps(payload, indent=2) + "\n", encoding="utf-8"
    )
    return dest


def load_result(shot_id: str, shots_dir: Optional[Path] = None) -> dict[str, Any]:
    path = shot_dir(shot_id, shots_dir) / "result.json"
    if not path.is_file():
        raise FileNotFoundError(shot_id)
    data = json.loads(path.read_text(encoding="utf-8"))
    return build_shot_result(**data)


def load_meta(shot_id: str, shots_dir: Optional[Path] = None) -> dict[str, Any]:
    path = shot_dir(shot_id, shots_dir) / "meta.json"
    if not path.is_file():
        raise FileNotFoundError(shot_id)
    return json.loads(path.read_text(encoding="utf-8"))


def raw_png_path(shot_id: str, shots_dir: Optional[Path] = None) -> Path:
    path = shot_dir(shot_id, shots_dir) / "raw.png"
    if not path.is_file():
        raise FileNotFoundError(shot_id)
    return path


def latest_shot_id(shots_dir: Optional[Path] = None) -> Optional[str]:
    ids = list_shot_ids(shots_dir)
    return ids[-1] if ids else None


def latest_result(shots_dir: Optional[Path] = None) -> Optional[dict[str, Any]]:
    sid = latest_shot_id(shots_dir)
    if sid is None:
        return None
    return load_result(sid, shots_dir)


def load_fixture_result() -> dict[str, Any]:
    path = FIXTURES_DIR / "sample_result.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    return build_shot_result(**data)


def seed_demo_shot(shots_dir: Optional[Path] = None) -> dict[str, Any]:
    """Copy fixture assets into shots/shot_NNNNN if no shots exist."""
    root = shots_dir or SHOTS_DIR
    existing = latest_result(root)
    if existing is not None:
        return existing
    fixture = load_fixture_result()
    raw = FIXTURES_DIR / "sample_raw.png"
    dest_id = fixture.get("shot_id") or format_shot_id(1)
    fixture["shot_id"] = dest_id
    save_shot(
        result=fixture,
        raw_image=raw,
        meta={
            "demo": True,
            "source": "fixtures/sample_result.json",
            "unix_ts": fixture["unix_ts"],
        },
        shots_dir=root,
    )
    return load_result(dest_id, root)


def record_demo_shot(shots_dir: Optional[Path] = None) -> dict[str, Any]:
    """Arm/capture in --demo: persist a new shot from the fixture oracle."""
    root = shots_dir or SHOTS_DIR
    fixture = load_fixture_result()
    sid = next_shot_id(root)
    now = time.time()
    result = build_shot_result(
        shot_id=sid,
        unix_ts=now,
        ok=True,
        error=None,
        ball_speed_mph=fixture["ball_speed_mph"],
        vla_deg=fixture["vla_deg"],
        carry_yd_est=fixture["carry_yd_est"],
        total_yd_est=fixture["total_yd_est"],
        confidence=fixture["confidence"],
        ghost_px=fixture["ghost_px"],
        pulse_gap_s=PULSE_GAP_S,
    )
    save_shot(
        result=result,
        raw_image=FIXTURES_DIR / "sample_raw.png",
        meta={
            "demo": True,
            "source": "fixtures/sample_result.json",
            "armed_ts": now,
        },
        shots_dir=root,
    )
    return result
