# Colony Charter — events rewrite sheet for GPT (2026-11-13)

**For:** the coding agent the user runs on their Windows PC (GPT/Codex), in parallel with Claude.
**Ask, in the user's words:** the events feel thin. The stories are bland, the rewards are peanuts and the
penalties don't sting. Make every event feel substantial: a real scene, real stakes, a real choice.

Read `CLAUDE.md` first (paths, commands, working rules). Everything below is specific to this job.

## 1. Scope, branch, files

- Branch `v17-events` from the latest `v17-fix-tips` (pull request
  [Konstantiy1453/brave-new-world#2](https://github.com/Konstantiy1453/brave-new-world/pull/2)). Push it and tell
  the user the branch name when done.
- Change **only** `game/data/v17/events.json`. Write your notes to `docs/v17/EVENTS_REWRITE.md`.
- Claude is changing other files at the same time (renderer, map, interface, `contract.json`), so touch nothing
  else. If an event needs a mechanic the engine does not have, do not code it: describe it under "Requests" in
  your notes (the option or condition key you would want and what it should do), and leave it out of the data.
- House rules: stage explicit paths (never `git add -A`); commits `v17: events: <what>`; Chinese only in
  player-facing strings, English ids; JSON in UTF-8, 2-space indent, non-ASCII written as is (the file
  round-trips with Python `json.dumps(data, ensure_ascii=False, indent=2)` plus a final newline).

## 2. How the engine uses events (`game/simulation/events_v2.gd`)

**Drawing.** Every 20 days the colony has a 55% chance of an event. Only definitions in this run's deck count:
each run leaves out a definition with probability 1 − `chance` (default 0.65). Then:
- a definition must have cooled down since it last opened (`cooldown_days`, default 1,200);
- its `conditions` must match at least one settlement, which becomes the event's place;
- incidents are at least 60 days apart;
- among the candidates, `weight` decides.

**Pausing.** A `notice` never pauses. A `decision` pauses when `critical` is true or the player asks for every
decision to pause.

**Timing.** At `deadline_days` the node's `default` choice is applied automatically.

**Definition:**

```json
"crack": {
  "version": 1,                 // never change for an existing id (saves check it)
  "type": "chain",              // "short" (one node) or "chain" (several)
  "category": "incident",       // opportunity | incident | dilemma | discovery
  "kind": "decision",           // decision | notice
  "critical": true,             // decisions only: pauses the game
  "cooldown_days": 99999,       // >= 60; 99999 = once per run
  "weight": 4,                  // 1-4
  "chance": 0.65,               // optional; share of runs that have it at all (< 1.0 unless code calls it)
  "conditions": {"min_day": 200, "road": true},
  "nodes": {
    "start": {
      "title": "零点八毫米的裂缝",   // unique across the whole file
      "text": "……",                   // the scene; 30+ chars (test), aim for 80-220
      "choices": [ {"id": "limit", "label": "限载，排期维修", "pay": 180.0, "next": "repaired", "delay": 60}, … ],
      "default": "risk",              // id of a choice in this node
      "deadline_days": 15
    },
    "repaired": { … }
  }
}
```

**Units.**
- **Money:** `pay` and `reward` are scaled to the colony. **300 = one day of the colony's recent income**: the
  engine multiplies by max(1, mean income of the last 30 days ÷ 300). So 3,000 means about ten days of income
  at any stage of the game.
- **Goods:** amounts are in **hundreds of tonnes**: `{"materials": 30}` is 3,000 t, and the interface shows
  tonnes. Goods keys: `ore`, `copper`, `crystal`, `food`, `materials`, `parts`, `components`, `alloy`,
  `machinery`, `pharma`.
- **Option text:** the card prints each option's numbers automatically under its label, so labels name the
  action (≤ 14 characters), not the numbers.

**Option keys** (one choice can combine several):

| Key | What it does |
|---|---|
| `pay` / `reward` | Money out / in, scaled as above |
| `goods_cost` | Taken from the place's stock; the option is refused if the stock is short |
| `goods_reward` | Delivered to the place's stock |
| `lose_goods` | Lost from stock, up to what there is |
| `effects` | List of `{kind, factor, duration_days, maintenance}`. `factor` 1.2 = +20%; `duration_days` 0 = permanent; `maintenance` = money a day. Kinds: `water`, `farm`, `mine`, `processor`, `port`, `power`, `all`, `appeal`, `research`, `export_price`, `road_capacity`. Production kinds apply to the place; `road_capacity` and `export_price` to the whole colony |
| `admit_workers` / `admit_scientists` | People arrive (use `beds` to require free beds) |
| `workers` | Needs this many free crews |
| `train_scientists` | Crews retrain as research teams |
| `research_points` | Added to the running project (topics cost 160-1,600 points) |
| `research_lead` | Puts a technology card on the table (a real tech id) |
| `tech_gift` | Hands over a gift technology: only `red_ball_express`, `fast_freighters`, `bulk_freighters` |
| `investigate` + `work` | Reserves that many research teams; with 3 teams the work takes about `work` days (fewer teams, longer), then moves to `next` and counts as surveyed |
| `requires_survey` | Option needs a finished investigation in this event |
| `build` | Orders a building of that kind at the place, at its normal cost; waits for it, then `next` |
| `order` | A parts delivery contract `{amount, price, days}` (see `industry`) |
| `next` + `delay` | Goes to another node after `delay` days |
| `next` + `alt` + `chance` | `next` with probability `chance`, otherwise `alt` (a gamble) |
| `ending` | Closes the event with this short outcome (2-8 characters); other events can test it with `previous` |
| `set_wage`, `distrust`, `pollution` | Wage level; company distrust (keep between −5 and +2); planet pollution points |
| `close_roads`, `clear_closure`, `shorten_closure` | Road closures at the place |
| `revise_deposits` | `[low, high]`: reserves of visible deposits × a factor in that band |
| `reveal_hidden` | Uncovers the place's hidden deposits |
| `found_enterprise`, `sell_rights`, `order_action` | Special; see the events that use them |

**Condition keys:**
- **Colony and time:** `min_day`, `settlements`, `exports`, `imports`, `contract_stage`, `status`, `previous` (`"event_id:ending"`).
- **The place:** `building`, `mine`, `scientists`, `population`, `children`, `attractiveness`, `employment`, `wage_below`, `frontier`, `residential`, `coast`, `river`, `arid`, `cold`, `wet`.
- **Research:** `research_active`, `lacks_tech`.
- **Transport:** `road`, `land_road`, `sea_link`.
- **Other:** `hidden_deposit`, `pollution_stage`, `no_enterprise`, `trigger_only` (only code opens it).

## 3. What to deliver

1. **Rewrite every definition** (86 today) so it reads as a scene:
   - **Content:** a named person or crew, a place in the colony, what is at stake, and one concrete detail
     (a reading on a gauge, a smell, a sound).
   - **Length:** node text 80-220 characters.
   - **Chains:** let later nodes remember earlier choices.
   - **Endings:** short and meaningful.
   - **Tone:** a near-future frontier colony under a company charter. Practical people, dry humour, real
     consequences; no real brands, places or politics.
2. **Raise the stakes** to these ranges (money in days of income; 300 = one day):

   | Event | Money | Goods | Effects |
   |---|---|---|---|
   | Small notice | 1-4 days (300-1,200) | 10-50 (1,000-5,000 t) | ±5-10% for 15-45 days |
   | Decision | 5-15 days (1,500-4,500) | 30-150 | ±10-25% for 30-90 days |
   | Chain climax | 15-40 days (4,500-12,000) | 100-400 | ±15-40% for 60-180 days, or permanent up to ±10% |

3. **Make every decision a real choice:**
   - No dominant option: each option costs something (money, goods, time, crews, research teams, distrust,
     pollution, or risk).
   - At least a third of decisions have a gamble (`next`/`alt`/`chance`).
   - Incidents must hurt, and must offer a way to soften the blow at a price.
4. **Add at least 15 new definitions**:
   - at least 6 chains of 3-5 nodes, spread over early (day < 360), mid and late game;
   - several that use the colony's newer systems: roads and docks (`land_road`, `sea_link`), research, frontier
     outposts, pollution, contract stages.
   - The harness asks for at least 60 short definitions and 10 chains in total.
5. **Keep the total in proportion.** Over a ten-year run, events should add or take, net, roughly 5-10% of the
   colony's income. Big rewards come with real costs or risk; the quick harness must still pass its money and
   award rows (section 5).
6. **Notes** in `docs/v17/EVENTS_REWRITE.md`:
   - a table of every event (id, category, what changed, money range in days);
   - the new events;
   - any requests for new mechanics;
   - test and harness results, each labelled with how it was run.

## 4. Hard rules (break them and saves or tests fail)

1. **Saves:** never delete or rename a definition id or a node id, and never change a definition's `version`.
   Saves hold open events by id, node and version.
2. **Structure:**
   - every `next` and `alt` names a node of the same definition;
   - `default` names a choice of its node;
   - effect kinds come only from the list above.
3. **Writing rules the tests enforce:**
   - titles unique across all nodes;
   - text at least 30 characters (keep it under 240);
   - never the old job names 工人, 研究员 or 科学家 (write 工程队, 研究团队, 殖民者, 技术员…);
   - every `research_lead` names a real technology.
4. **Cooldowns and chances:** `cooldown_days` ≥ 60. Each run must still leave about a third of the
   definitions out (the deck test allows 25-55%), so keep `chance` near the default unless code calls the event.
5. **Events code or tests depend on.** Keep their ids, nodes, choice ids, keys and `ending` strings. Rewrite
   their `title`, `text` and `label` freely. Change their numbers only if the suites below still pass; if a test
   pins a number, put it back and note it.
   - **Opened by code:** `rockfall` (roads), `smog_season`, `acid_rain`, `dead_bay` (pollution). Keep
     `trigger_only: true` and `chance: 1.0`.
   - **Opened and played by tests:**
     `appointment_gift`, `archaeology`, `archive_grant`, `blank_ridge`, `breakthrough`, `canteen`,
     `company_audit`, `crack`, `dust`, `equipment_failure`, `flu_season`, `freight_labels`, `industry`, `liner`,
     `market_day`, `meteor_shower`, `migrant_group`, `price_window`, `pump_seal`, `quiet_channel`,
     `red_ball_loop`, `seed_crate` (also the tutorial), `supply_delay`, `water`, `workshop`.
   - **Endings other events test:** `water` must keep its ending 「配水协议」, because `quiet_channel` requires
     `water:配水协议`.
   - **Gift events:** `red_ball_loop`, `retired_freighters`, `stranded_bulker` keep their `tech_gift` and
     conditions.

## 5. How to check (PowerShell, project root)

```powershell
python -c "import json; json.load(open('game/data/v17/events.json', encoding='utf-8'))"
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1 -Only v17_events,v16_events_tests,v16_event_acceptance,v16_event_history_probe,v16_event_order_probe,v16_flow,sim_tests,v17_tutorial,v18_systems,v19_transport -Jobs 4
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1
$env:APPDATA = 'D:\勇敢新世界\evidence\v17\userdata_tests'
& 'D:\勇敢新世界\tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe' --headless --path game --script res://tests/balance/run_balance.gd -- --quick --label=events-rewrite
```

**What must hold:**
- The suites pass as on the branch you started from. `v19_payback` and the harness's labour lever already miss;
  that is known and is in `docs/v17/BALANCE.md`.
- In the harness, these rows still pass:
  - `Events` (≤ 1 pause per 40 days, ≥ 25 distinct, 60 short and 10 chains, ≥ 25% off each run);
  - `Audits`, `Money`, `Balanced award, normal`, `Distrust`.

**How to report:** say plainly what ran, and label it (automated test, balance harness). The harness rewrites
`docs/v17/BALANCE.md`; commit that with your work.

## 6. The bar, by example

Today's `road_thieves` is two lines: three trucks lost cargo; patrol (¥130) or drive in convoy (−20% road
capacity for 45 days). A rewrite at the bar:

- **Node `start`, 「第三车队的空箱」:** 第三车队到站，封条完好，四箱精密部件却不见了。司机老马说夜里在废弃中转站停过二十分钟给电池保温，回来时车门好好的。调度室都知道，那个中转站最近夜里有灯。再这样下去，没人肯跑夜车。
  - 雇巡逻队 — pay 2,400; ending 「巡逻护路」.
  - 车队编组 — effects `road_capacity` 0.8 for 60 days; ending 「编组通行」.
  - 设下诱饵 — pay 900, `next` `caught` / `alt` `burned`, chance 0.6, delay 20.
- **Node `caught`:** the thieves were a crew from the colony's own outpost, selling parts to a passing ship.
  - 交给公司 — distrust −1, reward 1,500 (the company refunds the losses), but `appeal` 0.95 for 90 days in the
    outpost.
  - 内部处理 — no money; the crew works off the debt (`mine` 1.1 for 60 days), but word gets out
    (`distrust` +1).
- **Node `burned`:** the decoy was spotted. `lose_goods` parts 30; a choice between paying for patrols after all
  and letting the convoys crawl.

Each option has a price, one has a gamble, the money is days of income rather than pocket change, and the
follow-up remembers who the thieves were.
