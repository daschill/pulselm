# Courses PulseLM can legally use

## Use this: OpenGolfAPI (ODbL 1.0)

Free, no key for reads. ~16,800 US courses with scorecards and tee yardages.

- Search: `GET https://api.opengolfapi.org/v1/courses/search?q=bethpage`
- Detail + holes: `GET /v1/courses/{id}` and `/v1/courses/{id}/holes`
- PulseLM proxy: `GET /api/v1/courses?q=…` and `GET /api/v1/courses/<id>`
- Attribution required: OpenGolfAPI / © OpenStreetMap contributors (ODbL)
- Share-alike if we ship a derived database

What we get: **name, location, par, hole yardages** (blue/white tees). That is enough to set the 500 yd range pin to a real hole (e.g. Bethpage Black 4 = ~424 yd from the open scorecard).

Featured in the app: Bethpage Black, Bethpage Red, Pebble Beach (scorecard facts only).

USGS LIDAR (public domain) can later build heightmaps. OpenGolfSim course-terrain-tool exists for that. OSM golf polygons are coarse, not Tour-accurate greens.

## Do not copy into PulseLM

| Source | Why not |
|---|---|
| GSPro community `.course` files | Licensed for GSPro, not redistribution |
| E6 / TGC / Awesome Golf meshes | Paid/licensed 3D |
| Stracka / Golf Intelligence greens | Commercial API |
| Trademarked 3D replicas (Augusta, etc.) | Need a license even if OSM has a pin |

Those apps remain the place to *play* 18 photoreal holes. PulseLM uses open **scorecards as practice targets**.
