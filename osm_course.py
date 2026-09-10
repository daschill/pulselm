"""OSM golf geometry (ODbL) → hole map in yards.

Fairways, greens, bunkers, water, trees, tees. Cached. If Overpass is empty,
a synthetic hole is still generated so every round has a full layout.
"""

from __future__ import annotations

import json
import math
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Callable, Optional

from courses import ATTRIBUTION, course_with_holes, default_pin_yd

OVERPASS = "https://overpass-api.de/api/interpreter"
M_TO_YD = 1.0936132983377078
CACHE = Path(__file__).resolve().parent / "courses_cache"

FetchFn = Callable[[str], dict[str, Any]]


def _get_json(url: str) -> dict[str, Any]:
    req = urllib.request.Request(url, headers={"User-Agent": "PulseLM/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _overpass(lat: float, lng: float, *, fetch: Optional[FetchFn] = None) -> dict[str, Any]:
    q = (
        f'[out:json][timeout:40];('
        f'way["golf"](around:900,{lat},{lng});'
        f'way["leisure"="golf_course"](around:900,{lat},{lng});'
        f'node["natural"="tree"](around:700,{lat},{lng});'
        f');out tags geom;'
    )
    url = OVERPASS + "?data=" + urllib.parse.quote(q)
    fn = fetch or _get_json
    return fn(url)


def _ll_to_yd(lat: float, lon: float, lat0: float, lon0: float) -> tuple[float, float]:
    """East, north yards from origin."""
    east_m = (lon - lon0) * 111_320.0 * math.cos(math.radians(lat0))
    north_m = (lat - lat0) * 110_540.0
    return east_m * M_TO_YD, north_m * M_TO_YD


def synthetic_hole(par: int, pin_yd: float) -> dict[str, Any]:
    pin = float(pin_yd)
    half = 18.0 if par == 3 else 28.0 if par == 4 else 32.0
    fairway = [
        [-half * 0.45, 8],
        [half * 0.45, 8],
        [half, pin * 0.92],
        [half * 0.55, pin + 8],
        [-half * 0.55, pin + 8],
        [-half, pin * 0.92],
    ]
    green = []
    for i in range(16):
        a = 2 * math.pi * i / 16
        green.append([12 * math.cos(a), pin + 8 * math.sin(a)])
    green.append(green[0])
    bunkers = [
        [[-22, pin - 12], [-8, pin - 18], [-6, pin - 6], [-20, pin - 2], [-22, pin - 12]],
        [[14, pin - 8], [26, pin - 14], [28, pin - 2], [16, pin + 2], [14, pin - 8]],
    ]
    trees = []
    for t in range(10, int(pin), 18):
        trees.append([-half - 12, float(t)])
        trees.append([half + 14, float(t) + 8])
    return {
        "source": "synthetic",
        "fairways": [fairway],
        "greens": [green],
        "bunkers": bunkers,
        "water": [],
        "rough": [],
        "trees": trees,
        "tees": [[0.0, 0.0]],
        "hole_line": [[0.0, 0.0], [0.0, pin]],
        "max_along_yd": pin + 30,
        "max_offline_yd": 60,
    }


def _hole_axis(elements: list[dict[str, Any]], hole_num: int) -> Optional[tuple[dict, dict]]:
    candidates = []
    for e in elements:
        tags = e.get("tags") or {}
        if tags.get("golf") != "hole":
            continue
        geom = e.get("geometry") or []
        if len(geom) < 2:
            continue
        ref = str(tags.get("ref") or "").strip()
        name = str(tags.get("name") or "")
        if ref == str(hole_num) or name.endswith(f" {hole_num}") or f" {hole_num}" in name:
            return geom[0], geom[-1]
        candidates.append((geom[0], geom[-1]))
    if hole_num - 1 < len(candidates):
        return candidates[hole_num - 1]
    return None


def build_hole_map(
    elements: list[dict[str, Any]],
    *,
    hole_num: int,
    par: int,
    pin_yd: float,
) -> dict[str, Any]:
    axis = _hole_axis(elements, hole_num)
    if axis is None:
        syn = synthetic_hole(par, pin_yd)
        syn["hole"] = hole_num
        syn["par"] = par
        syn["pin_yd"] = pin_yd
        return syn
    tee, green = axis
    lat0, lon0 = float(tee["lat"]), float(tee["lon"])
    ge, gn = _ll_to_yd(float(green["lat"]), float(green["lon"]), lat0, lon0)
    length = math.hypot(ge, gn) or 1.0
    ux, uy = ge / length, gn / length

    def to_ao(lat: float, lon: float) -> list[float]:
        e, n = _ll_to_yd(lat, lon, lat0, lon0)
        along = e * ux + n * uy
        offline = e * uy - n * ux
        return [round(offline, 1), round(along, 1)]

    buckets = {
        "fairways": [],
        "greens": [],
        "bunkers": [],
        "water": [],
        "rough": [],
        "trees": [],
        "tees": [],
        "hole_line": [],
    }
    pin = max(pin_yd, length)
    for e in elements:
        tags = e.get("tags") or {}
        kind = tags.get("golf") or tags.get("natural")
        geom = e.get("geometry") or []
        if e.get("type") == "node" and kind == "tree":
            pt = to_ao(float(e["lat"]), float(e["lon"]))
            if -80 <= pt[0] <= 80 and -40 <= pt[1] <= pin + 80:
                buckets["trees"].append(pt)
            continue
        if not geom:
            continue
        ring = [to_ao(float(p["lat"]), float(p["lon"])) for p in geom]
        alongs = [p[1] for p in ring]
        offs = [p[0] for p in ring]
        if max(alongs) < -30 or min(alongs) > pin + 90:
            continue
        if min(offs) > 90 or max(offs) < -90:
            continue
        if kind == "fairway":
            buckets["fairways"].append(ring)
        elif kind == "green":
            buckets["greens"].append(ring)
        elif kind == "bunker":
            buckets["bunkers"].append(ring)
        elif kind in ("water_hazard", "water"):
            buckets["water"].append(ring)
        elif kind == "rough":
            buckets["rough"].append(ring)
        elif kind == "tee":
            buckets["tees"].append(ring[0])
        elif kind == "hole":
            buckets["hole_line"] = ring
    if not buckets["fairways"]:
        syn = synthetic_hole(par, pin)
        buckets["fairways"] = syn["fairways"]
    if not buckets["greens"]:
        syn = synthetic_hole(par, pin)
        buckets["greens"] = syn["greens"]
    if not buckets["trees"]:
        syn = synthetic_hole(par, pin)
        buckets["trees"] = syn["trees"]
    if len(buckets["trees"]) > 120:
        buckets["trees"] = buckets["trees"][:: max(1, len(buckets["trees"]) // 120)]
    buckets.update(
        {
            "source": "osm",
            "hole": hole_num,
            "par": par,
            "pin_yd": pin_yd,
            "max_along_yd": pin + 40,
            "max_offline_yd": 80,
            "attribution": "© OpenStreetMap contributors (ODbL) via Overpass",
        }
    )
    return buckets


def hole_map_for_course(
    course_id: str,
    hole_num: int,
    *,
    fetch_course: Optional[FetchFn] = None,
    fetch_osm: Optional[FetchFn] = None,
) -> dict[str, Any]:
    course = course_with_holes(course_id, fetch=fetch_course)
    holes = course.get("holes") or []
    hole = next((h for h in holes if int(h["hole"]) == int(hole_num)), None)
    par = int((hole or {}).get("par") or 4)
    pin = float((hole or {}).get("pin_yd") or default_pin_yd(par, hole_num))
    lat, lng = course.get("latitude"), course.get("longitude")
    syn = synthetic_hole(par, pin)
    syn.update(
        {
            "ok": True,
            "course_id": course.get("id"),
            "course_name": course.get("name"),
            "hole": int(hole_num),
            "par": par,
            "pin_yd": pin,
            "license": "ODbL-1.0",
            "attribution": ATTRIBUTION,
        }
    )
    if lat is None or lng is None:
        return syn
    CACHE.mkdir(parents=True, exist_ok=True)
    cache_path = CACHE / f"{course_id}.osm.json"
    try:
        if cache_path.is_file() and fetch_osm is None:
            osm = json.loads(cache_path.read_text(encoding="utf-8"))
        else:
            osm = _overpass(float(lat), float(lng), fetch=fetch_osm)
            if fetch_osm is None:
                cache_path.write_text(json.dumps(osm), encoding="utf-8")
        built = build_hole_map(
            osm.get("elements") or [],
            hole_num=int(hole_num),
            par=par,
            pin_yd=pin,
        )
        built.update(
            {
                "ok": True,
                "course_id": course.get("id"),
                "course_name": course.get("name"),
                "license": "ODbL-1.0",
                "attribution": ATTRIBUTION + " · © OpenStreetMap contributors",
            }
        )
        return built
    except Exception:
        return syn
