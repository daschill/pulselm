# PulseLM

Indoor golf launch monitor + native **iOS** sim. The iPhone is the app: photoreal 500-yard range, ball flight, HIT practice, and **GSPro OpenConnect :921** so normal launch monitors can send shots here.

## iOS app

Open `ios/PulseLM/PulseLM.xcodeproj` on a Mac (team `3H3PMHR6RY`, bundle `app.pulselm.PulseLM`).

- **Range** — first-person 500 yd range, tracer, HIT
- **Play** — OpenGolfAPI course search (scorecards / pins, not licensed GSPro/E6 meshes)
- **Shots** — last shot + session
- **Connect** — OpenConnect listener + Garmin Approach R10 Bluetooth
- First launch: settings walkthrough (name, units, club, pin, monitor)

### Launch monitors

PulseLM speaks **GSPro OpenConnect v1** on **TCP 921**. In the monitor (or its PC app) pick GSPro / OpenAPI / OpenConnect, server = the iPhone Wi-Fi IP shown in Connect.

Works with anything that already talks OpenConnect, including:

Garmin R10 / R50, Rapsodo MLM2PRO, Foresight GC2/GC3/GCQuad, Bushnell Launch Pro, Uneekor EYE XO/MINI/QED, SkyTrak / SkyTrak+, FlightScope Mevo+, Square, Full Swing KIT, Trackman (sim), ProTee VX, GolfJoy.

**Garmin Approach R10** can also pair over Bluetooth on the phone (no extra software). HIT still works with no hardware.

## Optional Pi hardware

Budget path: **4× OV9281 global-shutter + 24 GHz CW radar** (Camarray + dual-strobe). See [docs/BUDGET.md](docs/BUDGET.md) and [docs/wiring.md](docs/wiring.md).

```text
pip install -r requirements.txt
python pulselm.py --demo --r10
```

`--demo` serves `fixtures/sample_result.json` and does not use GPIO. Flask default `0.0.0.0:8080` (`--port 18080` if 8080 is taken). `--r10` also listens OpenConnect on **TCP 921** and `POST /api/v1/r10`.

Missing values are JSON **`null`**, not `0`.

## Tests

```text
python -m pytest tests -q
```

## License of courses

Hole maps/scorecards from [OpenGolfAPI](https://opengolfapi.org) (ODbL). We do **not** redistribute GSPro/E6 3D meshes.
