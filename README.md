# PulseLM

Indoor golf launch monitor on the cheapest capture path: Raspberry Pi 3 + OV9281 dual-strobe. The **iPhone 15 Pro is display only** (native iOS app + optional Safari LAN page). It is not the camera.

Two 2 µs 850 nm flashes, 2000 µs apart, in one **OV9281 global-shutter** exposure produce two ball dots. Ball speed is `px_dist * mm_per_px / 0.002` s, converted to mph. Vertical launch angle is `atan2`. Carry/total are derived from those launch conditions. HLA is estimated only when blob-size photometry plus a calibrated `camera_distance_mm` exist; otherwise HLA, spin, and club stay JSON `null` (never `0`).

## Hardware

- Camera: InnoMaker **CAM-MIPIOV9281V2** (OV9281 global shutter MIPI) on Pi CSI.
- GPIO14 → 100 Ω → IRLZ44N gate, 10 kΩ pulldown. Strobe.
- GPIO15 → camera TRIG.
- 850 nm LEDs on a **separate 12 V** supply. **Never** drive LEDs from Pi 5 V.

See [docs/wiring.md](docs/wiring.md).

Not this product: rolling shutter, OS04C10, ESP32-CAM, Pi Cam v2/v3, iPhone as sensor, BLE, Camera2, radar.

## Run (this host / CI)

```text
pip install -r requirements.txt
python pulselm.py --demo
```

`--demo` serves `fixtures/sample_result.json`, writes `shots/shot_NNNNN/{raw.png,meta.json,result.json}`, and **does not use GPIO**.

Flask listens on **0.0.0.0:8080** with CORS (Pi 3; iPhone Safari is display only). Override with `--host` / `--port` if 8080 is already taken on a workstation (Windows IP Helper `portproxy` on 8080 is a known conflict; `--port 18080` works).

| Method | Path | Notes |
|--------|------|--------|
| GET | `/` | Display + driving range; includes ball speed |
| GET | `/api/v1/health` | Health |
| GET | `/api/v1/range` | Landing from latest ShotResult (`along_yd`, `offline_yd`) |
| GET | `/shot/latest` | ShotResult JSON |
| GET | `/shot/<id>` | ShotResult JSON |
| GET | `/shots` | List |
| GET | `/shot/<id>/raw.png` | Capture |
| POST | `/arm` | Capture (demo: clone fixture) |
| POST | `/calibrate` | `{"mm_per_px": 1.8}` or known length |

On the Pi 3, omit `--demo` and install the unit:

```text
sudo cp systemd/pulselm.service /etc/systemd/system/pulselm.service
sudo systemctl daemon-reload
sudo systemctl enable --now pulselm.service
```

Point the native iOS app (`ios/PulseLM`) or Safari at `http://<pi-ip>:8080` (display only). Enable the sensor with `dtoverlay=ov9281` in `/boot/config.txt` or `/boot/firmware/config.txt` (see [docs/wiring.md](docs/wiring.md)).

## iOS app

Open `ios/PulseLM/PulseLM.xcodeproj` on a Mac. Bundle id `app.pulselm.PulseLM`. The app GETs `/shot/latest`, POSTs `/arm`, and maps `carry_yd_est` + `hla_deg` onto a driving range (`RangeLanding.swift`, same formula as `range_landing.py`). Null HLA lands on the target line. No AVCapture / BLE / radar.

## Workflow

`.grok/workflows/cheap-hardware-launch-monitor.rhai` — survey specialists + two-vote adversarial verify. Smoke-check with `validate_only` and `args.root`.

## ShotResult (`pulselm.shot.v1`)

`shot_id`, `unix_ts`, `ok`, `error`, `ball_speed_mph`, `vla_deg`, `hla_deg`, `spin_rpm`, `spin_axis_deg`, `club_speed_mph`, `face_deg`, `path_deg`, `carry_yd_est`, `total_yd_est`, `confidence`, `ghost_px`, `pulse_gap_s`.

Missing values are JSON **`null`**, not `0`. `pulse_gap_s` is `0.002`. Spin, spin axis, club speed, face, and path stay `null` on this hardware. HLA is `null` unless `camera_distance_mm` plus two blob diameters are supplied.

## Tests

```text
python -m pytest tests -q
```
