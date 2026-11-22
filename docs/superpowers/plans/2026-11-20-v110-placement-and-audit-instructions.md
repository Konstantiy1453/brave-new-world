# 1.10: free placement and the November 20 audit

The user's brief of 2026-11-20 against the Windows 1.10 "Bay" preview (`ColonyCharter-1.10.0-preview-20261120-bay`).
Free settlement placement is a release requirement and comes first; it is verified on the packaged
build before it is called done. Every other item follows in the order below and is reported plainly as
usable, partial or failing in the handoff.

## Rules that hold throughout

- Same as `2026-11-19-v110-bay-first-instructions.md`: deterministic, audited, numbers in data, English
  identifiers and Chinese player text, tests for each rule, one DECISIONS line per call.
- The world seed reproduces the geography; the player chooses where on it to settle. Recommended
  sites stay as shortcuts.
- A position is stored as the site's own `lat`/`lon`; every system that is keyed by a site (district,
  plots, roads, lights, saves) keeps working because a placed settlement gets a site record of its own.

## Order

1. **Free placement, simulation.** `site_gen.site_at(world, rules, lat, lon, id)` builds a site at the
   coordinate from the world's own grid: terrain, water, coast and landmass from the cell, plots from
   the slots around the exact point, deposits from the planetary geology. `Sites.ground_view` reports a
   coordinate (terrain, slope, fresh water, coast, known signals, distance to infrastructure,
   eligibility with a specific reason); `Sites.settle_at` founds there (capital or expedition). Routes
   end at the exact coordinates. Saves carry the new sites (the save validator allows them).
2. **Free placement, interface.** A click on a marker still selects it; a click on ordinary terrain on
   the globe or the flat map selects the ground under the pointer (inverse of the map projections) and
   clears the marker selection. The ground panel shows the report and the founding button acts only on
   what it shows. Expeditions: departure town, route, cost and travel time before dispatch.
3. **Verification on the packaged build.** A driver clicks the real interface in the shipped PCK: the
   seed 3 regression, capitals on the globe and on the flat map in two fresh games (two positions from
   one old candidate area), an unsuitable position refused, outposts inland and coastal after the
   normal unlock, save, quit, reload. Records go to `docs/v17/placement/`.
4. **Audited bugs.** First-shipment notices from a real consignment; a dependent mine road recomputed
   when the main road's mine is cancelled; crews use freight's route availability; net growth from the
   actual change; the farm forecast with harbour catch, other production, stock targets, queued
   facilities and the delivered import price; commissions while blocked; the water lesson's stages.
5. **Night lights at play zoom**; normal-play captures; the tutorial's bay opening; stage three.
6. **Larger systems**: radius slider; per-resource geology, prospecting, offshore extraction, nickel and
   cobalt; districts; farmers and population units; crew dispatch beyond buildings; local events.
7. **Handoff**: the exact build tested, placement records, saves, captures, results, plain status.
