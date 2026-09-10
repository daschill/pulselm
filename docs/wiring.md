# PulseLM wiring — 4× OV9281 + 24 GHz radar

Indoor launch monitor. The iPhone is **display only** (`http://<host>:8080` or the native app). It is not a camera.

Product sensors: **four OV9281 global-shutter cameras** (dual-strobe) **plus a 24 GHz CW Doppler**. Rolling shutter, OS04C10, ESP32-CAM, Pi Cam v2/v3, and iPhone-as-sensor stay out.

## Four cameras

| Cam | Role | What it measures |
|---|---|---|
| 0 | Side-on, strobed | Two-dot ball speed, VLA |
| 1 | Side-on stereo mate (~80 mm baseline) | HLA (Z from disparity) |
| 2 | Face-on / down-the-line | HLA, face if markings |
| 3 | High-behind | Club path (two-dot on the head) |

- Modules: **OV9281 global shutter** (InnoMaker CAM-MIPIOV9281V2 or Arducam OV9281).
- Quad CSI: **Arducam Camarray** (four OV9281 on one CSI). Pi 3 is bandwidth-tight; **Pi 5 / CM4** is the intended host for 4-cam.
- Shared **GPIO15 → every J3 TRIG+**, TRIG− to GND. One exposure, four frames.
- Overlay: `dtoverlay` for the Camarray / ov9281 stack in `/boot/firmware/config.txt`.

## Radar (24 GHz CW)

- Module: 24.125 GHz CW Doppler (CDM324-class / Infineon BGT24 I/Q).
- Place **behind the tee, looking downrange**. IF/I-Q into a USB sound card or ADC; peak `fd` → `v = fd * c / (2 * f0)`.
- Ball peak → `ball_speed_mph` (preferred over two-dot when both exist).
- Club peak (same beam or a second module on the club path) → `club_speed_mph`.
- Radar does **not** invent spin. `spin_rpm` only from a visible ball mark between the two 2 µs flashes.

## Camera (legacy single OV9281)

Single-cam dual-strobe still works (`--demo` and Pi 3 CSI). Fusion then leaves HLA/spin/club JSON null unless radar/stereo data is posted to `POST /api/v1/fuse`.

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
