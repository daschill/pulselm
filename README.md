# PulseLM Week 1

Indoor golf launch monitor. Raspberry Pi 3 captures; **iPhone 15 Pro is display only**.

Two 2 µs 850 nm flashes, 2000 µs apart, in one **OV9281 global-shutter** exposure produce two ball dots. Ball speed is `px_dist * mm_per_px / 0.002` s, converted to mph. Vertical launch angle is `atan2`. HLA, spin, and club stay `null`.

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
| GET | `/` | Display page; includes ball speed |
| GET | `/api/v1/health` | Health |
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

Point iPhone Safari at `http://<pi-ip>:8080` (display only). Enable the sensor with `dtoverlay=ov9281` in `/boot/config.txt` or `/boot/firmware/config.txt` (see [docs/wiring.md](docs/wiring.md)).

## ShotResult (`pulselm.shot.v1`)

`shot_id`, `unix_ts`, `ok`, `error`, `ball_speed_mph`, `vla_deg`, `hla_deg`, `spin_rpm`, `spin_axis_deg`, `club_speed_mph`, `face_deg`, `path_deg`, `carry_yd_est`, `total_yd_est`, `confidence`, `ghost_px`, `pulse_gap_s`.

Missing values are JSON **`null`**, not `0`. `pulse_gap_s` is `0.002`. Week-1 nulls: HLA, spin, spin axis, club speed, face, path.

## Tests

```text
python -m pytest tests -q
```
