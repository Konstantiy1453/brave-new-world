# The bay at night, through ordinary play (2026-11-20)

**Label: ORDINARY PLAY, source project, screenshot viewed.** Nothing in these frames was written
into the game's state by hand. The staged-fixture sheets in `../clean` and `../labels` are a different
thing: there the homes, people and harbour were put into a copy of the state to show what a grown
town looks like.

How the stages were reached (seed 260129, the world's first coastal start, site 11):

- The balanced bot from the balance harness runs the colony from the landing.
- Two ordinary orders go through `Sim.act`, as a player's clicks would: a home on day 3, and the
  small harbour once that home is lived in.
- The stages are the first days the game's state shows each event:

| Stage | Day | People | Lights | New homes lit | Ship |
|---|---|---|---|---|---|
| Landing | 2 | 60 | 10 | 0 | none |
| First home lived in | 55 | 61 | 18 | 1 | none |
| First cargo at the harbour | 75 | 71 | 19 | 1 | 938 t of iron ore loaded, ¥ 74 |

Within each view the camera, the local time (midnight at the town), the exposure and the weather
(clouds off) are the same at every stage, so only the town changes. Views:

- the globe at its default distance;
- the flat map at its closest zoom;
- the district from the land side towards the quay.

Captured at 1920×1080 with `game/tests/art/capture_nightscape.gd --play=on --labels=off --clip=on`.

**What changed between the stages, measured on the frames:**
- Globe, landing → first home: 1,397 pixels change (229 by 16 levels or more), all near the town.
  The new warm light stands at the home's own plot (`town_globe_x3.webp`, three times enlarged).
- Flat map, landing → first home: 2,458 pixels (358 strongly).
- In the audited 1.10.0 build both of these were identical to the landing, pixel for pixel. A home
  then needed half a window's worth of people before any window lit.
- First home → first cargo: the quay's compact cool lights and the ship at the berth (globe 632
  pixels, flat map 1,025).

**Files:**
- `play_<stage>_<view>.webp`: each frame at full resolution.
- `compare_<view>.webp`: the three stages side by side, titled.
- `town_<view>_x3.webp`: the town enlarged three times.
- `report.json`: the capture's own record.

The clips `delivery/v17/bay-night-play-ship-arrival.mp4` (the district's ship sailing in) and
`delivery/v17/bay-night-play-globe-zoom.mp4` (the globe from its default distance down to the town)
use the day-75 state.

**Seen and not fixed:**
- The ship at the berth sits on the quay's lamps and saturates to a white dot about 8 px across on
  the globe and the flat map, larger than the lamps it sits on.
- The landing camp's warm lights lie about 1.5° west of the facilities, as the district places them.

Human playtest: NOT_RUN. Looking at these on a real GPU on Windows: not done.
