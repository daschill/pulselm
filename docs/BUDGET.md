# PulseLM as a budget launch monitor

Street budget tier (2026): Garmin Approach R10 ~$599, Rapsodo MLM2PRO ~$500–700 + subscription, Mevo+ well above that. Those units use Doppler radar and/or marked-ball cameras. They estimate or measure spin. They want indoor ball flight of several yards.

PulseLM’s lane is **sub-$150 indoor photometry** (Pi 3 + OV9281 dual-strobe + 12 V IR LEDs, no subscription):

| Metric | Budget radar (R10 class) | PulseLM dual-strobe |
|---|---|---|
| Ball speed | Doppler | Two 2 µs ghosts / 0.002 s, global shutter |
| VLA | Radar | atan2 of the two dots |
| HLA | Radar / cameras | Only if blob size actually changes + `camera_distance_mm` |
| Spin | Estimated or marked-ball | **JSON null** (unmarked IR cannot see dimples) |
| Club | Radar behind the ball | **JSON null** |
| Carry | Flight model | Drag + lift using an *internal* typical-spin prior; `spin_rpm` stays null |
| Indoor net | Needs ball flight / alignment | One exposure, two flashes — works into a net |
| Subscription | Often $0–$200/yr | None |

Industry-leading **at this BOM** means: honest measured speed/VLA, a carry number in the amateur-driver band, session means/SD, CSV, native iOS range — not fake Trackman spin.

Hardware ceiling: one side-on OV9281 cannot become a GCQuad. Adding spin requires markings or a second view. Do not fill `spin_rpm` to look complete.
