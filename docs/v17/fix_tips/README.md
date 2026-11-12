# Fix tips (2026-11-12): screenshots

Runtime captures from the source project in a real window (Linux, Godot 4.5.1, software OpenGL under
Xvfb, 1600 × 900, 18 px text), cropped and saved as WebP. Evidence: source-project window, screenshots
viewed. Not run on Windows or a real GPU; human playtest NOT_RUN.

| File | What it shows |
|---|---|
| `top_bar.webp` | Top bar: each figure with its change a day (7-day mean), goods in tonnes, labour (劳动力) in place of population, iron, copper and crystal icons in their map colours |
| `region_edges.webp` | A generated world's region from low and far: the ground runs on to the horizon under haze, no edge or underside in view |
| `region_terraces.webp` | Plots cut into the slope as level terraces, service lanes between the rows, the quay on its shore |
| `lights_globe.webp` | Night side of the globe: three towns of different sizes, lit roads between them |
| `lights_town.webp` | One town close up: frayed outline, arms along the roads, suburbs, a street grid with dark blocks |
| `transport_levels.webp` | Transport page: two medium cargo docks with the large ones offered (needs 沿海航运), a road being paved with its next step |
| `research_gifts.webp` | Research page: finished topics with the gift technologies listed as 事件赠予 |
| `site_survey.webp` | Site card from orbit (±40%) with the survey order: price, days and the range it leaves |
| `colony_survey.webp` | A settled site after one survey (地面勘察 1 / 3 次 · ±12%) |
| `town_redball.webp` | Town with the red-ball gift: trucks painted red until their model arrives |
| `quay_shore.webp` | The quay of a cliff-top coastal town at the foot of the cliff, drawn larger for medium docks |

Made by developer capture scripts in the session scratchpad (the transport case: seed 1, a sea link
upgraded to medium docks, a mountain road being paved, two gifts granted); the region and lights
captures come from the commits `df73219` and `608d645`.
