# 1.11 decision records (2026-11-21)

Every figure here comes from a record file in this folder, made by the scripts in
`tools/verify/records/` (simulation records) and `tools/verify/decisions_driver.gd` /
`tools/verify/placement_driver.gd` (interface records). Labels as in `CLAUDE.md`. Human playtest:
NOT_RUN.

The build: `ColonyCharter-1.11.0-preview-20261121-decisions`, exported from commit `834ddd1`.
`ColonyCharter.pck` SHA-256 `10C9A62D8292DE32ACBF43334A39E8F9DA9DFD759A8101A260F009BA9841E08F`
(23,042,348 bytes); `ColonyCharter.exe` SHA-256 `78CCC576E8F8BFFD7EF6AD6F36EBD72A41E609A1052225A55B3407C96EA84065`
(the Godot 4.5.1 Windows runtime, the same file as in 1.10.0 and 1.10.1).

Matched branches start from the same 1.10.1 save (`save_files/`, written by the 1.10.1 code at commit
`3e3ab15`) and run the 1.10.1 code (a worktree at `3e3ab15`) and the 1.11 code side by side with the
same actions.

## Interface, on the shipped build

**Label: exported EXE** (Wine 9.0, Xvfb, Mesa llvmpipe; `exe/`) **and automated test on the
packaged PCK** (the Linux runtime of the same engine with `--main-pack`; `pck/`). Both drivers start
the game from its menu and act with real mouse and key events on the controls a player uses. A
record says which build answered (`build`: `packaged PCK` when the PCK has no `tests/`) and the PCK's
hash.

| Case | What it does | PCK | EXE |
|---|---|---|---|
| opening, south (decisions driver) | the site card at both seed-3 coasts clicked on the globe; the capital at 4.9780 S 163.5193 E through the card; the farm's four answers, the order, its withdrawal (cash and materials back once, audit clean), the order again; the food supply order from the town panel; the export goal's action with empty ground selected opens the capital's build page; a 2,000 t materials reserve; advance to the first delivery; save, quit, continue | 51 / 51 | see the handoff |
| opening, north | the same at 39.9747 N 122.1984 E with an iron mine | 49 / 49 | |
| tutorial | the tutorial from the menu, played to step 4 by input (wheel, two cards, the capital), saved, quit, continued; 「继续教程」 resumes step 4 in the same colony and town | 8 / 8 | |
| events | panels set not to pause; a communication arrives (day 233); its deadline passes with the events page open: the card turns into "到期，按默认处理：拆成备件" with "影响持续到 1年9月25日", one history row | 10 / 10 | |
| research | the page's 「可派」 count equals `Research.assignable`; the paid reshuffle says 「换 3 张 · ¥ 600」 and changes 3 cards | 7 / 7 | |
| capital, globe (placement driver) | capital on unmarked ground picked on the globe, save, quit, continue, both maps and the district agree | 14 / 14 | |
| capital, flat map | the same on the flat map | 14 / 14 | |
| regression, refusal, expeditions | see the handoff for the final counts | | |

## Seed 3: the two coasts

**Label: automated test (simulation).** 1.10.1 (balanced bot, `openings/*_1.10.1_balanced.json`):
the northern coast exported first on day 34; the fertile southern coast earned only local income and
failed on day 518 with no exports.

1.11 (`openings/seed3_*.json`, `records/opening_play.gd`): the player founds at the coordinate,
carries out the card's best plan, signs its supply order where it is one, and founds the second
town at the best unmarked point within 9° (no recommended site within 0.5°) as soon as the first
delivery is paid; the balanced bot keeps the colony running; each step waits for its cash.

| | North, 39.9747 N 122.1984 E | South, 4.9780 S 163.5193 E |
|---|---|---|
| Card | coastal plain, 138 m; 3 iron deposit plots, 2 farm plots (poor soil), rich fishery; iron estimate 633,146–2,416,826 t (orbital signal) | fertile valley, 587 m; 3 farm plots (medium soil, 681–938 t a farm a day), average fishery; no deposits |
| Plans offered, best first | iron export (2 mines, ¥5,250, first shipment day 21, 1,026 t, export goal day 284); catch order; food order | food supply order (2 farms, ¥6,500, first delivery day 26, 856 t, goal day 282); catch order |
| First genuine delivery | day 19: "第一车矿石：轻型铁矿场的 913 吨铁矿，在货运站卖出 ¥ 73" | day 25: "粮食供应合同首批交付：856 t，入账 ¥86，计入合同出口目标" |
| Second town | day 19, stage one, ¥73 exported, at 48.3617 N 117.1894 E (unmarked); its plan built by day 43 | day 25, stage one, ¥86 exported, at 12.341 S 155.5103 E (unmarked); its plan built on day 146, when the cash allowed |
| Stage one complete | day 139 | day 173 |
| Stage two complete | not by day 420 | day 411 |
| Exports by day 420 | ¥210,257 | ¥460,770 |
| Last 30 days to day 390 | export ¥7,865 · supply ¥4,691 · local ¥3,030 | export ¥12,215 · supply ¥58,748 · local ¥3,694 |

The southern food order renewed larger each time it was filled (40,000 t → 60,000 → 90,000 →
135,000 → 202,500 t, the second town's up to 360,000 t), lapsed once at 213,700 of 303,750 t and came
back at three quarters; food receipts kept the charter moving after the first payment (¥6,553 in the
30 days to day 90, ¥25,084 to day 210, ¥58,748 to day 390). The north stayed a mining economy
(export receipts first, supply second). Sales to residents are counted apart in both.

## Day 865 stock reserve (seed 9)

**Label: automated test (simulation)**, `reserve/`, `records/reserve_test.gd`. The capital keeps
50,000 t (500 units) of materials and of parts: 1.10.1's production target, 1.11's local reserve.
Thirty days hands-off (communications answered). The other town's three processing plants are
switched off, so every tonne comes from the capital; the capital has no order using materials or
parts (its one order, a water pump, used none).

| 30 days | 1.10.1 (target 50,000 t) | 1.11 (reserve 50,000 t) |
|---|---|---|
| Materials made | 27,378 t | 27,378 t |
| Materials exported | **27,378 t** | **0 t** |
| Materials in the warehouse | 9,000 → 9,000 t | 9,000 → 36,378 t |
| Parts made | 13,689 t | 13,689 t |
| Parts exported | **14,178 t** | **0 t** |
| Parts in the warehouse | 2,445 → 2,355 t | 2,445 → 16,534 t |

On day 865 the stock page and the trade both said: materials 9,000 t held, 0 t sellable. The audit
held every day in both. Both versions received the same 400 t of parts from outside the capital's
own flows on day 872 (a shipment already under way).

## Day 865 crews (seed 9)

**Label: automated test (simulation)**, `crews/`, `records/day865_crews.gd`. With the game paused, a
power station and then a freight port are ordered in the capital, whose one crew (#3) is building a
water pump (days 866–868).

| Order | Order screen before payment | Actual (hands-off and bot play) |
|---|---|---|
| Power station | ¥3,300 now; crew #3, 2nd in its queue behind the pump; starts 869, done 887 | 869 → 887 |
| Freight port | ¥6,061 now (¥6,000 + ¥61 of missing materials bought); crew #3, 3rd behind the pump and the power station; starts 888, done 910 | 888 → 910 |

## Day 865 fourth processing plant (seed 9)

**Label: automated test (simulation)**, `investment/`, `records/invest_branch.gd`. Branch *invest*
orders the plant on day 865; branch *skip* does not; both run 400 days answering communications only.
Communications' money is counted apart, because in 1.11 a loan offered by a communication (¥45,610,
"borrow") came on day 966 in one branch and day 1086 in the other.

| | 1.10.1 | 1.11 |
|---|---|---|
| Screen before ordering | payback 112 days (net ¥59.5 a day, cost ¥5,606) | ¥5,606 now; in service day 891; 5 of 8 posts staffed; inputs ¥24.1 a day; receipts ¥81.6 a day at recent prices; wages ¥12; upkeep ¥5; net ¥13.5–40.5 a day; payback **187–508 days from the order**, 161–482 from the start of production |
| Branch caught up (cash) | 209 days after the order | 222 days |
| Same, communications' money apart | 257 days | 194 days |
| Net a day once running (days 926–1265) | ¥24.4 | ¥16.8 (¥20.4 counting stock at market price) |

The new range contains the branches; the old figure was half of what the plant took. What the screen
shows accounts for the gap: only 5 of 8 posts can be staffed, the ore and copper it uses no longer
sell, and its materials sell into a market the other three plants already supply.

## Seed 260129: the contract outlook and advancing

**Label: automated test (simulation)**, `seed260129/`, `records/advance_check.gd`, from 1.10.1 saves.

- **Day 933, stage three** (11 of 14 technologies, the rest met). The contract page: technologies on
  track, the stage on day **1018**. "Advance to the next decision" with the stage as its milestone,
  answering only communications: it stopped on day 961 and 963 (10 and 15 research teams free, a
  choice the player would otherwise lose) and on day **1018**, "合同第 3 阶段完成". 1.10.1 reached it on
  day 1018 too. No order was given.
- **Day 611, stage three** (7 of 14 technologies). The page: on track for day 962; commissioning the
  running projects (¥600 a day) would make it day 787, **175 days sooner**. The balanced bot played on:
  day 993 without commissions, day 809 with every running project commissioned from day 611, **184
  days sooner** (1.10.1: 1018 → 842, 176 days).

## Event pacing

**Label: automated test (simulation)**, `pacing/`, `records/event_pacing.gd`: the balanced bot, six seeds,
720 days. An independent event is one the random draw brought; a forced interruption is a step that
stops the clock; "held back" is one the colony-wide cap kept in the panel instead.

| | 1.10.1 | 1.11 |
|---|---|---|
| First 30 days | 3 events, 3 forced | 0, 0 |
| First 90 days | 12, 5 forced | 2, 0 |
| First 360 days | 59, 21 forced | 24, 15 forced |
| First 720 days | 115 (1 set off by the colony), 29 forced | 60, 21 forced |
| Stage one, a month | 0.71 events, 0.26 forced | 0.12, 0.00 |
| Stage two, a month | 0.83, 0.23 forced | 0.54, 0.23 |
| Stage three, a month | 0.83, 0.06 forced | 0.35, 0.04 |
| Held back by the cap | — | 0 |
| The two-town water-station decision | — | 3 times |

The stage-three rate rests on 691 days of three seeds that reached it. By day 720 the 1.11 bot reached
stage three on 3 of 6 seeds, 1.10.1 on 5 of 6.
