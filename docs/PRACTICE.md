# Range practice (Trackman / GSPro / Awesome Golf feature set)

PulseLM’s range now covers the practice features those sims actually use, on top of R10 or camera shots:

| Feature | Source |
|---|---|
| 500 yd range, pins, tracer, flags | Trackman Range / GSPro range |
| Club select (Dr–LW) | Trackman My Bag / TPS |
| Data tiles: smash, apex, hang, land angle, total, curve | Trackman Practice 2026 extras |
| Dispersion rings (session vs tour ~8 yd / 15-hcp ~22 yd) | Trackman Range |
| Closest-to-pin | Awesome Golf / E6 skills |
| Longest drive | Awesome Golf / E6 |
| Random pin | GSPro shot randomizer / Trackman random mode |
| Session averages + CSV | GSPro practice stats |
| R10 OpenConnect ingest | GSPro Connect |

Not in this app (needs a full 3D engine + course library): 18-hole licensed courses, online multiplayer, putting green physics, night range. Those are GSPro/E6 products; PulseLM is the launch-monitor + range practice surface.

`GET /api/v1/practice?pin=250` returns tiles, closest, longest, dispersion, club list, games.
