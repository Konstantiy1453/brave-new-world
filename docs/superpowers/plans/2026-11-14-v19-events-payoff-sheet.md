# Colony Charter — events payoff sheet for GPT (2026-11-14)

**For:** the coding agent the user runs on their Windows PC (GPT/Codex), working in parallel with
Claude.

**Ask, in the user's words:** the rewritten events are "a bit more interesting now, but they still feel
a little thin. It's that 'bland to consume, wasteful to discard' problem."

**Read first:**
- `CLAUDE.md` (paths, commands, working rules);
- `docs/v17/EVENTS_DIAGNOSIS.md` (why the events feel thin, measured);
- your own package in `docs/v17/events_rewrite/`.

## 1. The problem in one table

Your rewrite made the stories 4.4 times longer and the costs 12 times bigger. It left what a choice
gives back where it was:

| | Before your rewrite | After it |
|---|---:|---:|
| Text per node, median | 60 characters | 264 |
| Typical cost, median | 0.6 days of income | 7.0 days |
| Endings that change nothing | 20% | 22% |
| Endings that leave something lasting | 13% | 12% |
| A typical effect | ±10% for 90 days | ±10% for 90 days |

So players pay more and read more for the same small, unseen nudge. Of 373 effects, 109 act on
吸引力 (appeal), a number nobody watches. The ten-node 「钻孔深处有一片星空」 ends in +8% power,
a research boost, ¥24,000, or (the default) +20% appeal for 240 days. 58 events are notices that
settle themselves.

**This job is not more words. It is payoffs:** what a choice leaves behind, how big it is, and an
ending scene that says so.

## 2. Scope, branch, files

- **Branch:** `v17-events-payoff`, from the latest `v17-fix-tips` (pull request
  [Konstantiy1453/brave-new-world#2](https://github.com/Konstantiy1453/brave-new-world/pull/2)). Push
  it and tell the user the branch name.
- **You change:**
  - `game/data/v17/events.json`;
  - `game/data/v17/techs.json`, only to append new gift technologies (section 4.4); never edit an
    existing technology;
  - your notes, in `docs/v17/EVENTS_PAYOFF.md`.
- **Claude, in parallel on `v17-fix-tips`,** builds the engine and interface for the new keys in
  section 3:
  - the ending scene card;
  - pausing at a node;
  - landmarks drawn in the town view and listed on the settlement;
  - effects shown where they act;
  - a map marker while a chain runs.

  Until that lands, today's engine ignores the new keys, so write them now. Do not code engine or
  interface changes yourself. If you need a mechanic that section 3 does not offer, describe it
  under "Requests" in your notes and leave it out of the data.
- **House rules:**
  - stage explicit paths, never `git add -A`;
  - commits read `v17: events: <what>`;
  - Chinese only in player-facing strings, English ids;
  - JSON in UTF-8 with a 2-space indent and non-ASCII written as is: the file must round-trip with
    Python `json.dumps(data, ensure_ascii=False, indent=2)` plus a final newline.

## 3. New keys you can use (the data contract)

Everything in the previous sheet (`docs/superpowers/plans/2026-11-13-v19-events-rewrite-sheet.md`,
section 2) still holds. These keys are new.

### 3.1 `outcome` on a choice: the ending scene

```json
{"id": "seal", "label": "原地封存作为共同遗产", "ending": "星图留在山里",
 "outcome": "工程队在孔口浇了最后一圈混凝土。沈砚把星图的复印件钉在测绘站的墙上，下面写着：原件在山里，别去打扰。"}
```

- **What it does:** 60–150 characters of what happened after the choice. It appears as a result
  card when the choice resolves and stays in the event history. Say what changed, who did it, and
  what is left.
- **Required** on every choice with `ending`.
- **Optional** on a choice with `next` and no `alt`, as a one-line bridge of 80 characters or fewer.
- **Never** on a choice with `alt`: the next node's text tells how the gamble came out.

### 3.2 `critical` on a node: the moment waits for the player

```json
"epilogue": {"title": "我们的点留在图上", "critical": true, "text": "…", "choices": [...], "default": "seal", "deadline_days": 30}
```

- **What it does:** when this node opens, the game pauses until the player answers, whatever the
  definition's own `critical` says. A finale is never settled by a default the player did not see.
- **Where:** each chain's deciding node, the one where the big ending is chosen. At most 2 nodes per
  chain.
- **Short events:** only when an option risks or wins 15 days of income or more.
- **Budget:** the harness allows one pause per 40 days on average, so keep the total near 40 nodes.

### 3.3 `landmark` on an ending choice: something that stays

```json
"landmark": {
  "id": "buried_sky_station",
  "name": "星窗观测站",
  "kind": "station",
  "text": "封存的钻孔上方立着一座小观测站，夜里那盏灯一直亮着。",
  "effects": [{"kind": "research", "factor": 1.12}]
}
```

- **What it does:** the place keeps the landmark for the rest of the game. It is drawn in the town
  view, listed on the settlement card with its `text`, and its `effects` act there permanently.
- **`id`:** English snake_case, unique across all events.
- **`name`:** 8 characters or fewer.
- **`text`:** one line of 60 characters or fewer: what stands there now.
- **`kind`:** one of eight, each drawn differently:

  | `kind` | What it looks like |
  |---|---|
  | `monument` | stele or obelisk |
  | `station` | small dome with a mast |
  | `seal` | capped shaft with barriers |
  | `garden` | trees or glasshouse |
  | `beacon` | tall mast with a light |
  | `archive` | small hall |
  | `wreck` | hull or debris |
  | `ruin` | standing remains |

- **`effects`:** 0 to 2 effects with the usual `kind` and `factor`, and no `duration_days`, since
  they are permanent. An optional `maintenance` (money a day) is allowed. Sizes are in the table in
  4.2.
- **Limits:** one landmark per ending; about 30 landmarks in the whole file, so they stay special.

### 3.4 `label` on an effect: a name the player sees where it acts

```json
{"kind": "mine", "factor": 0.75, "duration_days": 90, "label": "瓦斯限速"}
```

- **What it does:** effects are now listed on the town they touch and in the economy page's
  production lines, with the days left. The `label` is what is shown there.
- **Length:** 6 characters or fewer.
- **Optional:** without one, the event's title is shown. Write one for every effect that lasts 30
  days or more.

### 3.5 Keys the engine already has; use them more

`tech_gift` (with new gift technologies, 4.4), `admit_workers`, `admit_scientists`, `beds`,
`reveal_hidden`, `research_lead`, `research_points`, and `previous` conditions that open later
events.

## 4. What to deliver

### 4.1 Pay off what the story promises

- **Chains:** every chain's main ending (not its quit-early endings) leaves something lasting and
  visible: a landmark, a gift technology, people (`admit_*`), a revealed deposit, or a permanent
  effect.
- **The rare discoveries** must change how the colony plays: at least a gift technology, or a
  landmark with an effect at the top of its range. These are `nw_e_buried_sky`,
  `nw_e_valley_migration`, `nw_a_midnight_power`, `silent_probe`, `blank_ridge`, `archaeology`
  and `deep_shadow`.
- **Money-only endings** are fine as one option among others, never as the only reward of a chain.

### 4.2 Fewer, bigger effects

**Two sizes only:**
- **Small and brief:** ±5–15% for 15–60 days.
- **Big and lasting:** permanent, through a landmark or `duration_days: 0`, within this table:

  | Effect kind | Largest permanent factor |
  |---|---|
  | `all` | ±5% |
  | `export_price` | ±8% |
  | `mine`, `processor` | ±12% |
  | `farm`, `water`, `power`, `port`, `road_capacity` | ±15% |
  | `research`, `appeal` | ±20% |

**Rules for every effect:**
- Nothing smaller than ±5%: no ±3% dust.
- At most 2 effects per option.
- `appeal` in at most 15 options in the whole file, and only where the story is about the town's
  name, comfort or reputation.

**Price lasting gains properly:** a permanent effect is worth far more than a 90-day one. It costs
30–90 days of income, or the end of a long chain, or a real trade-off (another sector loses, upkeep).

### 4.3 No empty choices

- **Endings that change nothing:** at most 10% of all endings (22% today). The rest must change
  something.
- **Declining or sealing** must still close with an `outcome`, and may leave a small mark (a
  `monument` or `seal` landmark with no effect), or open a later event through `previous`.
- **Notices:** at most 35 (58 today). The strong ones become decisions; the weakest are merged or
  cut. A notice that stays costs nothing to accept, gives something small and brief, and has an
  `outcome`.
- **No dominant option:** every option still costs something or risks something.

### 4.4 Gift technologies (append to `techs.json`)

Add up to 8 new gift technologies for the big endings.

- **Copy an existing gift's shape** (`red_ball_express`): `gift: true`, `weight: 0`,
  `funding: 0`, `requires: []`, `minimum_staff: 3`, a `tier` and a `cost` for reference, a
  `category` and `branch`, a Chinese `name`, and a `description` starting 「事件赠予，无法研究。」.
- **Effects** come only from keys other technologies already use, as fractions, e.g.
  `{"mine_output": 0.1}`. Among them: `mine_output`, `farm_output`, `factory_output`,
  `research_speed`, `power_output`, `water_output`, `road_capacity`, `road_speed`, `sea_capacity`,
  `sea_speed`, `port_capacity`, `export_price`, `market_depth`, `immigration`, `births`,
  `build_speed`, `build_cost`, `upkeep`, `pollution`, `crystal_output`, `ore_output`,
  `copper_output`, `alloy_output`, `processor_output`, `foodworks`, `absorption`, `food_need`,
  `water_use` and `power_use`. Sizes are like a tier-3 or tier-4 technology: 0.1–0.25.
- **Hand them over** with `tech_gift`, and add the `lacks_tech` condition to any event that can
  give one, so it is never given twice.

### 4.5 An `outcome` for every ending

Every ending gets 60–150 characters of what happened, in the voice of the event's people.

### 4.6 Keep the total in proportion

- **Net effect:** over a ten-year run, events should add or take, net, about 5–10% of the colony's
  income.
- **The bots now weigh effects by their days**, so long penalties count against them. The quick
  harness must still pass its money and award rows (section 6).

### 4.7 Notes in `docs/v17/EVENTS_PAYOFF.md`

- a table of every event: what each main ending now leaves behind, and its size;
- the landmarks and gift technologies;
- the counts against the targets: empty endings, notices, `appeal` uses, critical nodes, landmarks;
- requests for new mechanics;
- test and harness results, each labelled with how it was run.

## 5. Hard rules (break them and saves or tests fail)

1. **Saves:**
   - never delete or rename a definition id or a node id;
   - never change a definition's `version`;
   - new nodes and new definitions are fine.
2. **Structure:**
   - every `next` and `alt` names a node of the same definition;
   - `default` names a choice of its node, and **every default stays free**: no `pay`, goods,
     `investigate`, `build` or admissions;
   - effect kinds come only from today's list;
   - landmark `kind` comes from section 3.3.
3. **Writing rules the tests enforce:**
   - titles unique across all nodes;
   - text at least 30 characters (your 226–343 is fine);
   - never the old job names 工人, 研究员 or 科学家;
   - every `research_lead` and `tech_gift` names a real technology (and a gift one for `tech_gift`).
4. **Cooldowns and chances:** as before: `cooldown_days` of at least 60, and each run still leaves
   about a third of the definitions out.
5. **Events that code or tests depend on:** everything in the previous sheet's rule 5 still holds.
   - Keep ids, nodes, choice ids and `ending` strings of `rockfall`, `smog_season`, `acid_rain` and
     `dead_bay`, and of the events the tests play.
   - The tests now walk the new paths of `crack`, `blank_ridge`, `water`, `archaeology` and
     `industry`, so keep those node and choice ids as they are now.
   - `water` keeps 「配水协议」.
   - The gift events keep their `tech_gift` and conditions.

## 6. How to check (PowerShell, project root)

```powershell
python -c "import json; json.load(open('game/data/v17/events.json', encoding='utf-8')); json.load(open('game/data/v17/techs.json', encoding='utf-8'))"
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1 -Only v17_events,v16_events_tests,v16_event_acceptance,v16_event_history_probe,v16_event_order_probe,v17_research,v19_transport,v16_flow,sim_tests -Jobs 4
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1
$env:APPDATA = 'D:\勇敢新世界\evidence\v17\userdata_tests'
& 'D:\勇敢新世界\tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe' --headless --path game --script res://tests/balance/run_balance.gd -- --quick --label=events-payoff
```

**What must hold:**
- The suites pass as on the branch you started from. Known misses, in `docs/v17/BALANCE.md`:
  - `v19_payback`, the light iron mine in year 6;
  - the four suites that fail only on Linux;
  - the harness rows Openings, Failure sloppy, Research-first and Services budget.
- In the harness, these rows pass:
  - `Events` (at most 1 pause per 40 days, at least 25 distinct, 60 short and 10 chains, at least 25%
    off each run);
  - `Audits`, `Money`, `Balanced award, normal` and `Distrust`.
- Until Claude's engine lands, landmark effects do not act and node pauses do not happen, so your
  harness slightly undercounts the gains. Say so in your notes.

**How to report:** say plainly what ran, labelled (automated test, balance harness). Commit the
`BALANCE.md` the harness rewrites.

## 7. The bar, by example

**The finale of 「钻孔深处有一片星空」** (`nw_e_buried_sky.epilogue`), today four quiet options
around +20% appeal.

At the bar, the node gets `critical: true`, and each ending leaves something different:

- **「保留装置改造本地供电」:** keeps its price (12,000 and goods) and gains a `station` landmark
  「星窗电站」 with `power` 1.15 and `research` 1.08 at the place. Outcome: the engineers wire the
  window into the grid; the town's lights flicker once at midnight, every night.
- **「保留资料推进本地研究」:** research points plus a new gift technology 「地层相位学」
  (`research_speed` 0.15, `crystal_output` 0.1). Outcome: the survey team's notebooks become the
  colony's first original science.
- **「整体移交发现与设备」:** ¥24,000 (80 days) and no landmark, because the window leaves the
  planet. Outcome: a sealed crate goes up the lift; the company sends a thank-you and nothing else.
- **「原地封存作为共同遗产」** (the default, still free): a `seal` landmark 「封存的星窗」, no
  effect, and `appeal` 1.1 permanently. Outcome: the borehole becomes a place people walk to on
  holidays.

**A notice that stays a notice:** 「落在防尘镜上的雨」 (`first_rain`).
- **Short holiday (pay 600):** `appeal` 1.12 for 30 days, labelled 「雨中假期」.
- **Collect the water (free):** `water` 1.2 for 30 days, labelled 「雨水入库」, with no ±5% all
  penalty.
- **Both options get an `outcome`.** That is all: small, brief, closed, and the player sees it end.

**A sealing ending that is not empty:** 「档案封存」-type endings get a `monument` landmark with no
effect, or a `previous` condition that brings the story back years later, plus an `outcome` that
says why the colony walked away.

Each main ending now leaves a thing the player can see and name, every effect worth having lasts or
is big enough to notice, and every story ends on a scene, not a tag.
