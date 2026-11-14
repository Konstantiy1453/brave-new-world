# Events rewrite (GPT, 2026-11-13)

A design package GPT wrote from `docs/superpowers/plans/2026-11-13-v19-events-rewrite-sheet.md`. The
user handed it over as a zip on 2026-11-13, and Claude integrated it the same day.

## In the game

`game/data/v17/events.json` is the package's full design, unchanged (`数据/事件扩展设计候选.json`
in the package, written in the house JSON format):

- 106 events, 249 nodes. The 86 existing events are rewritten and 20 are new.
- 14 long chains run to 6 nodes or more.
- Node texts run from 226 to 343 characters (60 before).
- Stakes are sized in days of income (300 reference money = 1 day): mostly 2–20 days, and up to
  80 for the rare discoveries.

Every existing event keeps its id, version and nodes, so saves with an open or finished event still
load. The design adds no field, condition, effect kind or option key that the engine lacks: it uses
the engine as it is. Its 18 requests for new mechanics are listed in `04_奖惩与开发交接.md`, and
none of them is implemented yet.

## In this folder

| File | What it is |
|---|---|
| `00_阅读指南.md` | GPT's reading guide: scale of the rewrite, the four chains to read first, the stake scale |
| `01_事件文案总册.md` | Every event's text with each option's numbers |
| `02_重点长链与分支图.md` | The 14 long chains: paths, endings, branch diagrams |
| `03_创作准则与奖惩标尺.md` | Writing rules, units and the scale of rewards and penalties |
| `04_奖惩与开发交接.md` | Per-event changes with cash in days of income, and the 18 mechanism requests |
| `事件文案阅读版.html` | The offline reading version (static HTML, no scripts) |
| `事件设计说明.json` | Per-event notes: theme, trade-off, integration limits, requests |

Left out of the repository:
- the text-only alternative (`数据/纯文案替换候选.json`, the 86 old events with new words and the
  old numbers);
- the volumes (`分卷/`);
- GPT's checking scripts, reports and screenshots (`校验/`);
- its snapshots of repository files (`参考基线/`).

Links in `00_阅读指南.md` to those folders do not resolve here.

The checks run on integration and the balance measurements are in `docs/v17/DECISIONS.md` (section
"1.9: the events rewrite"), `docs/v17/PROGRESS.md` and `docs/v17/BALANCE.md`.
