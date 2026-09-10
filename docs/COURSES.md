# Courses PulseLM can legally use

## Use this: OpenGolfAPI (ODbL 1.0)

Free, no key for reads. ~16,800 US courses with scorecards and tee yardages.

- Search: `GET https://api.opengolfapi.org/v1/courses/search?q=bethpage`
- Detail + holes: `GET /v1/courses/{id}` and `/v1/courses/{id}/holes`
- PulseLM proxy: `GET /api/v1/courses?q=…` and `GET /api/v1/courses/<id>`
- Attribution required: OpenGolfAPI / © OpenStreetMap contributors (ODbL)
- Share-alike if we ship a derived database

Hole **maps** (fairway, green, bunkers, water, trees) come from OpenStreetMap golf tagging (same ODbL). `GET /api/v1/courses/<id>/map?hole=4`. Bethpage Black is well mapped. If OSM has no hole, PulseLM still draws a full synthetic fairway/green/trees so every hole looks like a course, not a blank range.

`POST /api/v1/play/start {"course_id":"...","holes":18}` then hit balls (Arm or R10). Full 18-hole scorecard: `GET /api/v1/play`. 9-hole courses play the nine twice. Missing tee yardages get a par-based default so every hole is playable.

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
