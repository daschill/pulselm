# PulseLM Week 1 wiring (Pi 3 + OV9281)

Indoor dual-strobe launch monitor. The iPhone 15 Pro is **display only** (browser to `http://<pi>:8080`). It is not a camera, not a BLE sensor, and not part of the capture path.

## Camera

- Sensor: **OV9281 global shutter**, MIPI CSI-2 on the Raspberry Pi 3 CSI connector.
- Module: **InnoMaker CAM-MIPIOV9281V2**.
- TRIG: camera **J3** — **TRIG+** (3.3–5.0 V isolated input) to **GPIO15**, **TRIG−** to Pi GND.
- Overlay (Raspberry Pi OS): comment out `camera_auto_detect=1` and add `dtoverlay=ov9281` in `/boot/config.txt` or `/boot/firmware/config.txt`. Pi 3 has a single CSI connector (the default Unicam / CSI1 path).
- Forbidden on this project: rolling shutter, OS04C10, ESP32-CAM, Pi Camera v2, Pi Camera v3, iPhone as sensor, BLE, Camera2, a second camera, radar.

Global shutter is required so two 2 µs IR flashes in one exposure produce two crisp ball dots (not smeared streaks).

## Strobe MOSFET (GPIO14)

```
Pi GPIO14  ---- 100 ohm ---- IRLZ44N GATE
                              |
                         10 k pulldown
                              |
                             GND
```

- Logic: **GPIO14** → **100 Ω** series resistor → **IRLZ44N** gate.
- **10 kΩ pulldown** from gate to GND so the FET stays off at boot / GPIO reset.
- IRLZ44N source to GND. Drain switches the LED cathode (low-side switch).

## LEDs

- Emitters: **850 nm** IR LEDs aimed at the ball flight window.
- Supply: **separate 12 V** (wall adapter or dedicated pack) through the LED string / current-limiting resistors / constant-current driver, switched by the IRLZ44N.
- **Never use the Pi 5 V rail for the LEDs.** The 5 V pin cannot source the strobe current and will brown-out the Pi.

## Trigger

- **GPIO15** → InnoMaker **J3 TRIG+**. **TRIG−** → Pi GND.
- J3 is specified 3.3–5.0 V with on-board isolation; GPIO15 is 3.3 V and is in that range. Do not feed 12 V into TRIG+.

## Pulse train (one exposure)

Two flashes in a single global-shutter frame:

1. GPIO15 TRIG rises (exposure starts).
2. After a short settle (~80 µs), GPIO14 strobe **2 µs** high (flash 1).
3. **2000 µs** start-to-start later, GPIO14 strobe **2 µs** high (flash 2).
4. TRIG falls. Frame readout yields **two ball dots**.

`pulse_gap_s = 0.002`

Speed:

```
speed_mm_s = px_dist * mm_per_px / 0.002
ball_speed_mph = speed_mm_s * 3600 / (25.4 * 12 * 5280)
vla_deg = atan2(dy_up, dx)
```

Week 1: HLA, spin, and club are JSON `null`.

## Power / safety

- Common GND: Pi GND, MOSFET source, 12 V supply negative.
- Keep the 12 V LED current loop short and off the Pi PCB.
- Confirm polarity on the OV9281 flex before seating in the CSI connector (power off).
