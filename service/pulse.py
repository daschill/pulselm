"""Dual-strobe pulse train for OV9281 global-shutter capture.

Hardware (see docs/wiring.md):
  GPIO14 -- 100 ohm -- IRLZ44N gate, 10k pulldown to GND
  GPIO15 -- camera TRIG
  850 nm LEDs on a separate 12 V supply. Never use Pi 5 V for LEDs.

Timing: two 2 us flashes, 2000 us apart (start-to-start) in one exposure.
Ball speed uses pulse_gap_s = 0.002 as the time between the two dots.

GPIO / picamera2 are imported lazily so ``--demo`` runs on hosts without Pi libs.
"""

from __future__ import annotations

import time
from typing import Any, Callable, Optional

STROBE_PIN = 14
TRIG_PIN = 15
FLASH_WIDTH_US = 2
FLASH_GAP_US = 2000  # start-to-start
PULSE_GAP_S = FLASH_GAP_US / 1_000_000.0  # 0.002
EXPOSURE_SETTLE_US = 80
# Exposure must cover both flashes plus settle.
MIN_EXPOSURE_US = FLASH_GAP_US + 2 * FLASH_WIDTH_US + EXPOSURE_SETTLE_US + 500


def busy_wait_us(duration_us: float, clock: Callable[[], float] = time.perf_counter) -> None:
    """Spin until ``duration_us`` microseconds have elapsed."""
    if duration_us <= 0:
        return
    deadline = clock() + duration_us / 1_000_000.0
    while clock() < deadline:
        pass


def dual_flash_edges_us(
    flash_width_us: int = FLASH_WIDTH_US,
    flash_gap_us: int = FLASH_GAP_US,
    settle_us: int = EXPOSURE_SETTLE_US,
) -> list[tuple[str, int]]:
    """Return the intended edge timeline (no GPIO). Used by tests and docs.

    Times are microseconds from TRIG rising edge.
    """
    t0 = settle_us
    t1 = t0 + flash_gap_us
    return [
        ("trig_rise", 0),
        ("strobe1_rise", t0),
        ("strobe1_fall", t0 + flash_width_us),
        ("strobe2_rise", t1),
        ("strobe2_fall", t1 + flash_width_us),
        ("trig_fall", t1 + flash_width_us + 50),
    ]


def _require_gpio():
    try:
        import RPi.GPIO as GPIO  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "RPi.GPIO is required for live capture. Use --demo on non-Pi hosts."
        ) from exc
    return GPIO


def setup_pins(GPIO: Any) -> None:
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    GPIO.setup(STROBE_PIN, GPIO.OUT, initial=GPIO.LOW)
    GPIO.setup(TRIG_PIN, GPIO.OUT, initial=GPIO.LOW)


def fire_dual_strobe(
    GPIO: Any,
    *,
    flash_width_us: int = FLASH_WIDTH_US,
    flash_gap_us: int = FLASH_GAP_US,
    settle_us: int = EXPOSURE_SETTLE_US,
) -> None:
    """GPIO14 two 2 us flashes 2000 us apart; GPIO15 TRIG around the pair.

    Start-to-start gap is ``flash_gap_us`` so speed uses 0.002 s.
    """
    wait_between_us = flash_gap_us - flash_width_us
    if wait_between_us < 0:
        raise ValueError("flash_gap_us must be >= flash_width_us")

    GPIO.output(TRIG_PIN, GPIO.HIGH)
    busy_wait_us(settle_us)
    GPIO.output(STROBE_PIN, GPIO.HIGH)
    busy_wait_us(flash_width_us)
    GPIO.output(STROBE_PIN, GPIO.LOW)
    busy_wait_us(wait_between_us)
    GPIO.output(STROBE_PIN, GPIO.HIGH)
    busy_wait_us(flash_width_us)
    GPIO.output(STROBE_PIN, GPIO.LOW)
    busy_wait_us(50)
    GPIO.output(TRIG_PIN, GPIO.LOW)


def capture_dual_strobe_frame(camera: Optional[Any] = None) -> Any:
    """Trigger OV9281 + dual IR strobe and return one frame.

    Not used by --demo. Requires picamera2 / libcamera on the Pi 3 CSI path
    (InnoMaker CAM-MIPIOV9281V2). Rolling-shutter sensors are forbidden.
    """
    GPIO = _require_gpio()
    setup_pins(GPIO)
    try:
        if camera is None:
            from picamera2 import Picamera2  # type: ignore

            camera = Picamera2()
            config = camera.create_still_configuration(
                main={"size": (1280, 800), "format": "R8"},
            )
            camera.configure(config)
            camera.set_controls({"ExposureTime": MIN_EXPOSURE_US, "AnalogueGain": 1.0})
            camera.start()
            own_camera = True
        else:
            own_camera = False
        # Request a frame, fire strobes during the global-shutter window.
        fire_dual_strobe(GPIO)
        frame = camera.capture_array()
        if own_camera:
            camera.stop()
            camera.close()
        return frame
    finally:
        GPIO.cleanup()
