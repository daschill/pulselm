# PulseLM as a budget launch monitor

Street budget tier (2026): Garmin Approach R10 ~$599, Rapsodo MLM2PRO ~$500–700 + subscription, Mevo+ well above that. Those units use Doppler radar and/or marked-ball cameras. They estimate or measure spin. They want indoor ball flight of several yards.

PulseLM’s product sensors are **4× OV9281 global-shutter (Camarray) + 24 GHz CW Doppler**, still no subscription, BOM targeted under a Garmin R10:

| Metric | R10-class | PulseLM 4-cam + radar |
|---|---|---|
| Ball speed | Doppler | **Radar preferred**, dual-strobe cross-check |
| VLA | Radar | Side-on two-dot (cam 0) |
| HLA | Radar | Stereo pair (cam 0–1) or face-on (cam 2) |
| Spin | Estimated or marked-ball | Ball **mark** between 2 µs flashes; else JSON null |
| Club speed | Radar | 24 GHz club peak |
| Path / face | Some units | Cam 3 club two-dot path; face needs markings |
| Carry | Flight model | Drag + lift; `spin_rpm` published only if marked |
| Indoor net | Needs ball flight | Dual-strobe works into a net |
| Subscription | Often $0–$200/yr | None |

Do not fill `spin_rpm` from the carry prior. Radar + four global-shutter views are how this stack reaches HLA/club; unmarked IR blobs still cannot see dimple spin.
