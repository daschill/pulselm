"""Two-dot dual-strobe vision: speed from px_dist * mm_per_px / 0.002 s, VLA from atan2.

One global-shutter exposure with two IR flashes yields two ball dots (ghosts).
HLA, spin, and club metrics are out of scope for Week 1 and stay JSON null.
"""

from __future__ import annotations

import math
from typing import Any, Optional, Sequence

import numpy as np

from service.pulse import PULSE_GAP_S

# mm/s -> mph: 3600 s/h / (25.4 mm/in * 12 in/ft * 5280 ft/mi)
MM_S_TO_MPH = 3600.0 / (25.4 * 12.0 * 5280.0)
MPH_TO_MPS = 0.44704
M_TO_YD = 1.0936132983377078
# Extra g approximates aerodynamic drag for a Week-1 indoor carry estimate.
CARRY_G_EFF = 12.5
TOTAL_ROLL_FACTOR = 1.07
GOLF_BALL_DIAMETER_MM = 42.67


def px_distance(dot1: Sequence[float], dot2: Sequence[float]) -> float:
    return math.hypot(dot2[0] - dot1[0], dot2[1] - dot1[1])


def metrics_from_dots(
    dot1: Sequence[float],
    dot2: Sequence[float],
    mm_per_px: float,
    pulse_gap_s: float = PULSE_GAP_S,
) -> dict[str, float]:
    """Pure two-dot math. Image +y is down; world +y is up.

    speed_mm_s = px_dist * mm_per_px / pulse_gap_s
    ball_speed_mph = speed_mm_s * MM_S_TO_MPH
    vla_deg = degrees(atan2(dy_up, dx))
    """
    if pulse_gap_s <= 0:
        raise ValueError("pulse_gap_s must be positive")
    if mm_per_px <= 0:
        raise ValueError("mm_per_px must be positive")

    dx = float(dot2[0]) - float(dot1[0])
    dy_up = float(dot1[1]) - float(dot2[1])
    ghost_px = math.hypot(dx, dy_up)
    speed_mm_s = ghost_px * mm_per_px / pulse_gap_s
    ball_speed_mph = speed_mm_s * MM_S_TO_MPH
    vla_deg = math.degrees(math.atan2(dy_up, dx))
    carry_yd, total_yd = estimate_carry_total_yd(ball_speed_mph, vla_deg)
    return {
        "ball_speed_mph": ball_speed_mph,
        "vla_deg": vla_deg,
        "ghost_px": ghost_px,
        "pulse_gap_s": pulse_gap_s,
        "carry_yd_est": carry_yd,
        "total_yd_est": total_yd,
        "dx_px": dx,
        "dy_up_px": dy_up,
        "speed_mm_s": speed_mm_s,
        "mm_per_px": mm_per_px,
    }


def estimate_carry_total_yd(ball_speed_mph: float, vla_deg: float) -> tuple[float, float]:
    """Vacuum-like range with inflated g as a drag stand-in. Not a sim model."""
    v = ball_speed_mph * MPH_TO_MPS
    theta = math.radians(vla_deg)
    if v <= 0 or abs(math.sin(2.0 * theta)) < 1e-12:
        return 0.0, 0.0
    range_m = (v * v * math.sin(2.0 * theta)) / CARRY_G_EFF
    carry_yd = range_m * M_TO_YD
    return carry_yd, carry_yd * TOTAL_ROLL_FACTOR


def _label_connected(binary: np.ndarray) -> tuple[np.ndarray, int]:
    """4-connected component labels. binary is bool, True = foreground."""
    h, w = binary.shape
    labels = np.zeros((h, w), dtype=np.int32)
    parent: list[int] = [0]

    def find(x: int) -> int:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    next_label = 0
    for y in range(h):
        row = binary[y]
        for x in range(w):
            if not row[x]:
                continue
            left = labels[y, x - 1] if x else 0
            up = labels[y - 1, x] if y else 0
            if left and up:
                labels[y, x] = left
                union(left, up)
            elif left:
                labels[y, x] = left
            elif up:
                labels[y, x] = up
            else:
                next_label += 1
                parent.append(next_label)
                labels[y, x] = next_label

    remap = {}
    compact = 0
    out = np.zeros_like(labels)
    for y in range(h):
        for x in range(w):
            lab = labels[y, x]
            if lab == 0:
                continue
            root = find(lab)
            if root not in remap:
                compact += 1
                remap[root] = compact
            out[y, x] = remap[root]
    return out, compact


def find_two_dots(
    image: np.ndarray,
    threshold: Optional[float] = None,
) -> tuple[tuple[float, float], tuple[float, float], float]:
    """Return (dot1, dot2, confidence) ordered along +x (flight).

    ``dot1`` is the earlier ghost (smaller x). Confidence in [0, 1].
    """
    img = np.asarray(image)
    if img.ndim == 3:
        img = img.mean(axis=2)
    img = img.astype(np.float64)
    if threshold is None:
        threshold = max(float(np.percentile(img, 99.0)), float(img.max()) * 0.5, 8.0)
    binary = img >= threshold
    if not np.any(binary):
        raise ValueError("no bright pixels for ball dots")

    labels, nlab = _label_connected(binary)
    blobs: list[tuple[float, float, int, float]] = []
    for lab in range(1, nlab + 1):
        ys, xs = np.where(labels == lab)
        area = int(xs.size)
        if area < 3:
            continue
        cx = float(xs.mean())
        cy = float(ys.mean())
        brightness = float(img[ys, xs].mean())
        blobs.append((cx, cy, area, brightness))
    blobs.sort(key=lambda b: b[2] * b[3], reverse=True)
    if len(blobs) < 2:
        raise ValueError(f"need two ball dots, found {len(blobs)}")
    a, b = blobs[0], blobs[1]
    p1 = (a[0], a[1])
    p2 = (b[0], b[1])
    if p1[0] > p2[0]:
        p1, p2 = p2, p1
    areas = sorted([a[2], b[2]])
    area_ratio = areas[0] / max(areas[1], 1)
    conf = max(0.0, min(1.0, 0.55 + 0.45 * area_ratio))
    return p1, p2, conf


def render_two_dot_image(
    width: int,
    height: int,
    dot1: Sequence[float],
    dot2: Sequence[float],
    radius: int = 7,
    peak: int = 255,
) -> np.ndarray:
    """Synthetic 8-bit frame with two IR-like ball dots (for fixtures/tests)."""
    yy, xx = np.mgrid[0:height, 0:width]
    img = np.zeros((height, width), dtype=np.float64)
    for cx, cy in (dot1, dot2):
        r2 = (xx - cx) ** 2 + (yy - cy) ** 2
        img += peak * np.exp(-r2 / (2.0 * (radius / 2.2) ** 2))
    return np.clip(img, 0, 255).astype(np.uint8)


def analyze_frame(
    image: np.ndarray,
    mm_per_px: float,
    pulse_gap_s: float = PULSE_GAP_S,
) -> dict[str, Any]:
    dot1, dot2, confidence = find_two_dots(image)
    metrics = metrics_from_dots(dot1, dot2, mm_per_px, pulse_gap_s)
    metrics["confidence"] = confidence
    metrics["dot1"] = [dot1[0], dot1[1]]
    metrics["dot2"] = [dot2[0], dot2[1]]
    return metrics
