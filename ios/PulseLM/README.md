# PulseLM iOS

Native SwiftUI client for the Pi 3 OV9281 launch monitor. **Display only** — no camera, BLE, or radar.

- `Models/ShotResult.swift` — `pulselm.shot.v1` keys verbatim
- `Mapping/ShotMapping.swift` — `ball_speed_mph` 159.1608 → `"159.16"`
- `Mapping/RangeLanding.swift` — null HLA → on-line; else `carry * cos/sin(hla)`
- `Views/RangeView.swift` — driving range; landing from the shot payload
- Default monitor URL: `http://192.168.0.139:8080`

Open `PulseLM.xcodeproj` in Xcode 15+ (iOS 17). This Windows host cannot compile the app.
