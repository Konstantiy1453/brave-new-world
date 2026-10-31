# Colony Charter 1.8 — the user's brief and the acceptance bar

Written 2026-10-31 after the user played 1.7.1. Folders stay `docs/v17`, `evidence/v17`, `build/v17`, `delivery/v17`: `CLAUDE.md` allows writes only there.

## The request, verbatim

> First, a full run is still too short. Both from a gameplay standpoint and from a realistic one, building a city prosperous enough to serve as a capital within a one-year deadline is just too implausible.
>
> Second, pollution. It shouldn't really be one of the sources of distrust. It should be an exponential, outbreak-style debuff — its effect should be tiny at the start. After all, with only one or two human settlements on a planet that big, how much pollution could they possibly cause? It should only gradually blow up into a real problem in the late game.
>
> Also, the 300-day cycle I mentioned is too short. If the current build times stay as they are, roughly 6 to 8 years to build a complete colony and earn the governor qualification feels about right to me. And a 10× maximum fast-forward speed is clearly excessive — 5× or 6× at the very most, and the mid-tier speed should be 2× to 3×.
>
> Next, turn "workers" into "engineering crews" and "researchers" into "research teams" — those two are purely a naming change. Then, for resources like iron, copper, crystal, food, and also power, money and water, list them in a table at the top or in some dedicated spot, Stellaris-style, with the current total followed by the monthly change (+ or −).
>
> That distrust level could work like Rebel Inc. — a gauge standing at the side showing the real-time daily change. And I feel the distrust currently rises too fast.
>
> Don't make the research options such an explicit tech tree either. Make it more like Stellaris: split into industry, agriculture, construction, or some other division into three or four categories, and each time refresh three or four random techs per category; after picking a tech, assign the corresponding research team to work on it.
>
> Also, roads seem to get built a bit too fast. And island settlements shouldn't be treated as restricted starting points — water transport is perfectly possible too.
>
> Then there's that per-outpost building list I mentioned last time: pull it out into its own column, like the building list on each planet in Stellaris, with dates and a progress bar.
>
> I also think the build times could be stretched a bit more — that can serve as a driver, or at least a contributing factor, for slowing the game's pace down.
>
> As for events: first, not every event needs to fire in sequence every run. Some can be skipped, some can trigger. Second, the writing should be a bit more vivid, so it feels immersive.
>
> Overall, the core problem really is that the pace is too fast. My idea is to greatly expand the tech tree content as a way to lengthen the playtime. At the same time, a richer tech tree also enriches a whole range of gameplay — building categories, resource extraction, and even the types of buildings available in outposts or cities.
>
> I'd also prefer splitting outposts into two types: residential outposts, and frontier outposts — that is, mining or agricultural outposts. That way buildings can be allocated more appropriately to the matching outpost type.
>
> One more reminder about planet size: even though it doesn't look big on the map, the selectable planets actually have radii ranging from 60% to 130% of Earth's radius. Pay attention to the actual distances, calculated from the planet size ratio and the scale.

## Checklist

| # | Asked for | Where it lands |
|---|---|---|
| 1 | Governor in 6-8 years on standard | Five-stage contract, economy scale, harness bands |
| 2 | Pollution: not a distrust source; tiny early, exponential late | `simulation/pollution.gd`, planet-wide load |
| 3 | Speeds 1×, mid 2-3×, top 5-6× | `progression.json` `time` |
| 4 | 工人 → 工程队, 研究员 → 研究团队, names only | Every player-facing string |
| 5 | Resource table at the top: total, then monthly change | Top bar |
| 6 | Distrust gauge at the side, daily change, slower rise | Gauge widget, company rates |
| 7 | Research by category, 3-4 random cards, assign a team | `research.gd`, research page |
| 8 | Roads take real time | Road construction from distance |
| 9 | Islands are ordinary starts; water transport from the start | Validator, routes, expeditions |
| 10 | Per-settlement building column with dates and progress bars | Main screen column |
| 11 | Longer build times | `economy.json` |
| 12 | Events: run-to-run variety, vivid writing | Event deck, rewritten text, more events |
| 13 | Much larger technology pool feeding buildings and extraction | `techs.json`, new buildings |
| 14 | Residential and frontier settlements | Settlement `kind`, building `site_kinds` |
| 15 | Planets 0.6, 1.0 and 1.3 Earth radii, real distances | CC-GEO-2.2 |

## Acceptance bar (replaces §5.2 of the 1.7 brief)

Balance harness on fixed seeds, standard difficulty and medians unless stated. Years are 360 days.

| Area | Target |
|---|---|
| Balanced award | standard 2,160-2,880 days (6-8 years); easy 1,800-2,520; hard 2,520-3,240 |
| Floor | Rush bot never earns the award before day 1,440 |
| Openings | Balanced medians within 15%; best bot differs by opening |
| Failure | Passive bot: review by day 150-400, takeover by day 400-900. Sloppy bot: review on every difficulty, takeover on hard |
| Population | Meets the final goal at award; at least 300 by year 2 and 800 by year 4 |
| Labour lever | Wage 1.0× to 1.3× changes 360-day immigration by at least 20% |
| Research | Balanced: at least 40 technologies by award, every category used, research teams 10-20% of adults at award |
| Research-first | More technologies than balanced at award, award inside the standard band |
| Technology pool | At least 100 technologies in 4 categories; at least 30 new buildings; offers differ between seeds |
| Money | Reinvests at least 60% of operating surplus; income at year 6 at least 2.5× year 2 |
| Export mix | No good above 60% of export revenue after year 2 |
| Pollution | Output penalty under 2% through year 3 for balanced; never a company risk source; a no-control run reaches at least 15% by year 8 |
| Distrust | Largest daily rise in any balanced run at most 0.8 points |
| Events | At least 60 short events and 10 chains; each run has at least 25% of the pool switched off; two seeds differ in what fires; at most 1 pausing decision per 40 days; at least 25 distinct by award |
| Geography, 200 seeds | Radii 0.6, 1.0, 1.3 × 6,371 km; site counts as before; at least 3 start pairs on every seed; island sites can be starts |
| Roads | A typical first road takes 3-10 months to build; road trade-off row as before |
| Determinism | Replays byte-identical at 2,880 days; 1×, 3× and 6× identical |
| Audits | 0 errors in every harness run, including fuzz runs |
| Saves | At most 1.5 MB at day 2,880; save at most 100 ms, load at most 300 ms; autosave adds no frame over 50 ms |
| Responsiveness | Warm page at most 100 ms; cold region at most 1.0 s, no frame over 50 ms |
| Old saves | 1.7.0 and 1.7.1 saves load on their original worlds; 1.6 saves still migrate; originals unchanged |
| Tutorial | Headless run completes every step; skip and replay work. Human first run NOT_RUN until the user does it |

Evidence labels and working rules are unchanged: see `CLAUDE.md`.
