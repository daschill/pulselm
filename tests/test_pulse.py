"""GPIO pulse-train tests. No real RPi.GPIO — mock the pin sequence."""

from __future__ import annotations

import time

import numpy as np
import pytest

from service.pulse import (
    FLASH_GAP_US,
    FLASH_WIDTH_US,
    PULSE_GAP_S,
    STROBE_PIN,
    TRIG_PIN,
    busy_wait_us,
    capture_dual_strobe_frame,
    dual_flash_edges_us,
    fire_dual_strobe,
    setup_pins,
)


class FakeGPIO:
    BCM = "BCM"
    OUT = "OUT"
    LOW = 0
    HIGH = 1

    def __init__(self) -> None:
        self.events: list[tuple] = []
        self.mode = None
        self.warnings = None
        self.levels: dict[int, int] = {}

    def setmode(self, mode) -> None:
        self.mode = mode

    def setwarnings(self, flag: bool) -> None:
        self.warnings = flag

    def setup(self, pin: int, mode, initial=0) -> None:
        self.levels[pin] = initial
        self.events.append(("setup", pin, mode, initial))

    def output(self, pin: int, val: int) -> None:
        self.levels[pin] = val
        self.events.append(("out", pin, val, time.perf_counter()))

    def cleanup(self) -> None:
        self.events.append(("cleanup",))


class FakeCamera:
    def __init__(self) -> None:
        self.captured = 0

    def capture_array(self) -> np.ndarray:
        self.captured += 1
        return np.zeros((16, 16), dtype=np.uint8)


def test_pins_and_gap_constants():
    assert STROBE_PIN == 14
    assert TRIG_PIN == 15
    assert FLASH_WIDTH_US == 2
    assert FLASH_GAP_US == 2000
    assert PULSE_GAP_S == 0.002


def test_busy_wait_us_honors_fake_clock():
    ticks = [0.0]

    def clock() -> float:
        ticks[0] += 0.0000005  # 0.5 us per call
        return ticks[0]

    t0 = ticks[0]
    busy_wait_us(10, clock=clock)
    assert ticks[0] - t0 >= 10 / 1_000_000.0


def test_setup_pins_bcm_gpio14_gpio15_low():
    gpio = FakeGPIO()
    setup_pins(gpio)
    assert gpio.mode == FakeGPIO.BCM
    pins = {e[1] for e in gpio.events if e[0] == "setup"}
    assert pins == {STROBE_PIN, TRIG_PIN}
    for e in gpio.events:
        if e[0] == "setup":
            assert e[3] == FakeGPIO.LOW


def test_fire_dual_strobe_two_2us_flashes_2000us_apart():
    gpio = FakeGPIO()
    setup_pins(gpio)
    t_before = time.perf_counter()
    fire_dual_strobe(gpio)
    elapsed_us = (time.perf_counter() - t_before) * 1_000_000.0
    outs = [e for e in gpio.events if e[0] == "out"]
    pins_vals = [(e[1], e[2]) for e in outs]
    assert pins_vals == [
        (TRIG_PIN, FakeGPIO.HIGH),
        (STROBE_PIN, FakeGPIO.HIGH),
        (STROBE_PIN, FakeGPIO.LOW),
        (STROBE_PIN, FakeGPIO.HIGH),
        (STROBE_PIN, FakeGPIO.LOW),
        (TRIG_PIN, FakeGPIO.LOW),
    ]
    strobe_rises = [e[3] for e in outs if e[1] == STROBE_PIN and e[2] == FakeGPIO.HIGH]
    assert len(strobe_rises) == 2
    gap_us = (strobe_rises[1] - strobe_rises[0]) * 1_000_000.0
    # Start-to-start is 2000 us; allow OS scheduling jitter on Windows.
    assert gap_us == pytest.approx(2000.0, abs=1500.0)
    assert elapsed_us >= 2000.0

    edges = dual_flash_edges_us()
    by_name = {n: t for n, t in edges}
    assert by_name["strobe2_rise"] - by_name["strobe1_rise"] == 2000
    assert by_name["strobe1_fall"] - by_name["strobe1_rise"] == 2


def test_capture_dual_strobe_uses_injected_gpio_and_camera():
    gpio = FakeGPIO()
    cam = FakeCamera()
    frame = capture_dual_strobe_frame(camera=cam, gpio=gpio)
    assert frame.shape == (16, 16)
    assert cam.captured == 1
    assert any(e[0] == "cleanup" for e in gpio.events)
    outs = [(e[1], e[2]) for e in gpio.events if e[0] == "out"]
    assert (STROBE_PIN, FakeGPIO.HIGH) in outs
    assert (TRIG_PIN, FakeGPIO.HIGH) in outs


def test_live_capture_without_gpio_raises():
    with pytest.raises(RuntimeError, match="--demo"):
        capture_dual_strobe_frame(camera=FakeCamera())


def test_fire_dual_strobe_rejects_gap_shorter_than_width():
    gpio = FakeGPIO()
    setup_pins(gpio)
    with pytest.raises(ValueError, match="flash_gap_us"):
        fire_dual_strobe(gpio, flash_width_us=5, flash_gap_us=4)
