# Colony Charter 1.9 — Windows verification run (for the agent on the user's PC)

You are working in the Colony Charter repository on the user's Windows PC (project root
`D:\勇敢新世界`, branch `v17`). Version 1.9 was developed in a Linux cloud container, which cannot do
four things: run the Windows-recorded tests, bake the menu atlas with the Windows engine, export
the EXE and measure frame times on a real GPU, and run the full balance harness at full width. This
sheet is those jobs, in order, with what each result should be and **which way to fix** when it is
not. Work through it top to bottom; report at the end (§9).

Read first, in this order: `CLAUDE.md` (paths, commands, never-modify list, working rules),
`docs/v17/PROGRESS.md` (the 1.9 section), `docs/v17/DECISIONS.md` (the 1.9 sections: every value
there was a judgment call; do not undo one without a reason you write down).

## 0. Ground rules

- **Never modify** what `CLAUDE.md` lists: player saves under `%APPDATA%\ColonyCharter\v16`, `v17`
  and `v18` (1.9 only *reads* them and writes `v19`), `build\v16`, `delivery\` except
  `delivery\v17`, `versions\`, `docs\v16\`, existing files under `evidence\` (write only to
  `evidence\v17`), `tools\godot-4.5.1\`, the `1.6.0 baseline` commit and `v1.6.0` tag. Do not touch
  or stage `art_reserve\`.
- **Stage explicit paths; never `git add -A`.** Commit in small steps on `v17` as
  `v17: <area>: <what>`, ending with your tool's attribution line if it adds one. Push with
  `git push -u origin v17`.
- Tests and probes run with `$env:APPDATA = 'D:\勇敢新世界\evidence\v17\userdata_tests'` (the test
  runner does this itself). **The export does not**: open a fresh PowerShell for §6.
- A process that exits 0 while its log has `SCRIPT ERROR`, `FAIL` or a failed check is a failure.
- Numbers live in `game/data/v17/*.json`. Fix data before code, and code before tests. Never make a
  check pass by weakening it if it guards an invariant: the ledger audit, determinism (same seed and
  actions ⇒ identical state), save round trips, the old-save files staying untouched.
- Change one thing at a time, re-run what it touches, and add one line per decision to
  `docs/v17/DECISIONS.md` (`decision · reason · alternative rejected`).
- **Stop and ask the user** before: dropping a feature or a great work, changing a premise (for
  example removing the copy surcharge or the services budget), deleting or rewriting user data, or
  doing anything outside the repository.
- Label every result with its evidence: automated test · balance harness · source-project window ·
  exported EXE · screenshot viewed · human playtest (NOT_RUN unless the user played).

```powershell
cd D:\勇敢新世界
$env:Path = "C:\Program Files\Git\cmd;" + $env:Path
$engine = 'D:\勇敢新世界\tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe'
```

## 1. Get the branch and import

```powershell
git fetch origin v17
git checkout v17
git pull origin v17
git lfs pull
git status --short          # must be clean apart from art_reserve\ (never stage it)
git log --oneline -1        # write this hash into the report
& $engine --headless --path game --editor --import --quit
```

Expected: the import ends without `SCRIPT ERROR`. It may create `.uid` files for scripts added in the
cloud (for example `game/tests/art/frame_time_probe.gd.uid`): commit any new `*.uid` next to its
script (`v17: tests: uid for ...`).

## 2. Re-record the save fixtures (rules and save schema changed)

1.9 changed the money rules and moved saves to schema 5. The capture fixtures are recorded games and
must be re-recorded with the Windows engine (their world hashes are Windows hashes; Linux cannot
make them):

```powershell
$env:APPDATA = 'D:\勇敢新世界\evidence\v17\userdata_tests'
& $engine --headless --path game --script res://tests/make_fixtures_v17.gd
```

Expected: `V17_FIXTURES_RESULT errors=0`, and new
`game/data/v17/acceptance_{early,midgame,event,crisis,governor,late}.save`. Leave
`acceptance_geo20.save` and `acceptance_geo21.save` alone: they are 1.7 saves on purpose (they test
reading old saves). Commit the six files: `v17: tests: re-record capture fixtures under 1.9 rules`.

If a fixture cannot be reached (the script reports an error for one moment, for example "governor"
never comes because the bot is no longer awarded early enough), do not change the bot to force it:
report which moment failed and the day the run ended, and move on.

## 3. Bake the menu atlas

```powershell
& $engine --headless --path game --script res://tests/art/bake_menu_atlas.gd
& $engine --headless --path game --editor --import --quit
```

Expected: `BAKE_MENU_ATLAS D:\...\game\assets\generated\world_atlas_<hash>.png error=0`, then an
`.import` file beside it. Commit the PNG (Git LFS) and its `.import`:
`v17: art: bake the menu atlas with the Windows engine`. Check by eye: start the game from the
editor (or the EXE in §6); the planet behind the main menu must appear at full detail at once.

## 4. All test suites

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1 -Jobs 4
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1 -Window
```

Expected: **every suite passes**, including the four that fail on Linux only (`v17_saves`,
`v17_tutorial`, `v18_systems`, `world_v16_seed`), the seven `review_*` tools (they write to
`D:\` paths that exist here) and the four window suites. Logs are in `evidence\v17\tests\`.

Which way to fix a failure:

| What fails | Likely cause | Direction |
|---|---|---|
| A check that loads `acceptance_*.save` and compares an outcome (a day, a count, a balance) | The fixture or the expectation was recorded under 1.8 rules | Re-run §2 first. If it still fails, make the test read the value from `game/data/v17/` or from the fixture instead of a written-in 1.8 number; one line in DECISIONS. Never delete the check |
| A check about loading an old save, the log line 「1.8 存档按 1.9 规则继续经营」, schema 5, or `%APPDATA%\ColonyCharter\v19` | Real save bug | Fix `simulation/save_io.gd` / `save_migration.gd`, not the test. The original 1.8 / 1.7 files must stay byte-identical |
| `v19_money` | Real rules bug | Fix the simulation; the suite is the 1.9 rules contract |
| `v19_payback`: a building outside its band | This world is not the Linux world, so paybacks differ a little | See the payback table below |
| `sim_tests`, `ui_contract` determinism or "speed changed result" | A non-deterministic path | Find it and fix it. Suspects in 1.9: the great works' daily effect cache (`Megaprojects.effect`, keyed on day and state identity) and any dictionary iteration that depends on insertion order |
| `review_*` tools | Their own paths or a real finding | Read the tool's report; fix what it reports |
| A window suite's picture check | Rendering on this GPU | Look at the saved picture; fix the shader or the scene, not the threshold |

**Payback bands** (`v19_payback`, plan A2.2): the suite prints a table. Mines are checked in year 6,
factories in year 4, the rest in years 2, 4 and 6; band edges have 5% slack.

| Too short (pays back too fast) | Too long (never pays) |
|---|---|
| Raise that building's `cost` in `game/data/v17/economy.json` by the ratio needed (heavy mines: `maintenance` too) | Lower its `cost`, or raise its output (`rate` / `outputs`), or for commerce `spend` |

Keep any one change within ±30% of today's value; update the building's `description` if it quotes the
number; re-run `v19_payback`, `v19_money` and a quick harness (§7, `--quick`) before the full run.

## 5. Screenshots and frame times on this GPU

```powershell
& $engine --path game --script res://tests/art/capture_dynamics.gd -- --days=900
& $engine --path game --script res://tests/art/model_gallery.gd
& $engine --path game -- --dev --dev-script=res://tests/art/capture_pages_v19.gd
& $engine --path game -- --dev --dev-script=res://tests/art/capture_pages_v19.gd --days=1440
& $engine --path game --script res://tests/art/frame_time_probe.gd -- --size=1920x1080
```

Look at every picture in `evidence\v17\art\dynamics`, `evidence\v17\art\gallery` and
`evidence\v17\art\pages` (label: screenshot viewed). Things to check: the planet turns and has a
terminator, towns and roads light up at night, clouds and storms move, the region view has day,
night, traffic and smoke, buildings stand on their plots, and the economy page shows
「现金可支撑 N 天」, the administration line, the market rows with 「底价」 and 「钱花在哪」.

`frame_time_probe.gd` writes `evidence\v17\perf\frame_times.json` (mean and 95th-percentile frame
time, vsync off, every effect on and again with clouds off). The bar:

| Result at 1920×1080, every effect on | Verdict |
|---|---|
| ≥ 60 fps mean and p95 ≤ 25 ms in every view | PASS |
| 30–60 fps in some view | Report it; fix if a single cause stands out |
| < 30 fps in any view | MISS: fix before release |

Which way to fix a slow view (keep the effect, make it cheaper; never remove a feature without asking):

| Slow view | Where | Direction |
|---|---|---|
| Globe, clouds on | `CLOUDS_GLSL` in `game/world/shaders.gd` | One fbm octave fewer; fewer storm samples |
| Globe, clouds off too | Globe surface shader | Fewer noise lookups for detail; cheaper relief |
| Flat map | Flat map shader (about 20 texture reads a pixel) | Fewer hill-shading taps; reuse one lookup |
| Region | `game/world/region_view.gd`, `traffic.gd` | Fewer lamp lights or vehicles (`MAX_VEHICLES`), no shadows on small props, lower model LOD |

Also run the existing developer measure for saves and pages, as in 1.8:

```powershell
& $engine --path game -- --dev --dev-script=res://tests/perf_probe_v17.gd --perf-out=D:\勇敢新世界\evidence\v17\perf --perf-save=D:\勇敢新世界\game\data\v17\acceptance_late.save
```

and compare with the 1.8 bar in `docs/v17/V18_BRIEF.md`.

## 5b. Picture quality: the standard renderer and 高画质 (Forward+), added 2026-11-13

The game ships with Godot's Compatibility renderer as the default. 高画质 is Forward+, chosen in
「档案与显示设置 → 画质」. It is saved in `%APPDATA%\ColonyCharter\v19\graphics_override.cfg` and applies
after a restart. Check on this PC:

1. In the source project: run the frame-time probe once per renderer and keep both files.

   ```powershell
   & $engine --path game --rendering-method gl_compatibility --script res://tests/art/frame_time_probe.gd -- --size=1920x1080
   & $engine --path game --rendering-method forward_plus --script res://tests/art/frame_time_probe.gd -- --size=1920x1080
   & $engine --path game --rendering-method forward_plus --rendering-driver d3d12 --script res://tests/art/frame_time_probe.gd -- --size=1920x1080
   ```

   Same bar as §5. If Forward+ misses it, first try lowering the ambient occlusion (`HQ_AO` in
   `game/world/map_view.gd`) and the number of lamp lights (`MAX_LAMP_LIGHTS` in
   `game/world/region_view.gd`). Do not turn features off without asking.
2. In the exported EXE:
   - choose 高画质, press 「立即重启」, and check the settings page now says 「当前：高画质（Forward+）」;
   - compare the region at noon and at night with the standard renderer (screenshots with F12, label:
     screenshot viewed): bloom only on lights, soft shadows, warm lamp light on the ground at night,
     no washed-out colours.
3. Fallback: start the EXE with `--rendering-driver opengl3` while 高画质 is chosen. The game must run
   and the settings page must say the card could not run high quality.
4. Anti-aliasing: 「抗锯齿：高」 should show smooth edges on buildings, roads and shores in both
   renderers. Report the frame-time cost of 「高」 against 「关」 if it is over 15%.

## 6. Export and try the EXE

Open a **fresh** PowerShell (real `%APPDATA%`, the export needs it):

```powershell
cd D:\勇敢新世界
powershell -ExecutionPolicy Bypass -File tools\build_v17.ps1
```

Expected: `build\v17\ColonyCharter.exe` and `ColonyCharter.pck`. Then, by hand (label: exported EXE):

1. Before starting: if `%APPDATA%\ColonyCharter\v18` has saves, record their SHA-256
   (`Get-FileHash`). Do not open, copy over or delete them.
2. Start the EXE. The menu shows the newest save, a 1.8 one if 1.9 has none yet. Continue it: the
   log says 「1.8 存档按 1.9 规则继续经营」. Save. A new `%APPDATA%\ColonyCharter\v19\manual.save`
   appears; the v18 hashes are unchanged.
3. Start a new game, play a few in-game months at 3×: the globe turns, night lights come on, clouds
   move; open the economy, research, population and career pages; nothing errors.
4. Close the EXE. Compare the v18 hashes again.

Any change to a v18 file is a blocker: stop and tell the user.

## 7. Full balance harness

```powershell
$env:APPDATA = 'D:\勇敢新世界\evidence\v17\userdata_tests'
& $engine --headless --path game --script res://tests/balance/run_balance.gd -- --full --jobs=12 --label=1.9-windows-full
```

It writes `evidence\v17\balance\<timestamp>.json` and refreshes the results block in
`docs\v17\BALANCE.md` (10 seeds, 3 openings, 3 difficulties, the windfall case). Commit `BALANCE.md`
with the label in the message.

The rows and which way to move when one misses. Make **one** change, check it with a quick run
(`--quick --jobs=12 --label=<what you changed>`), then confirm with a full run.

| Row | Target | If it misses |
|---|---|---|
| Audits, Determinism | 0 errors; all replays identical | Blocker. Fix the code |
| Floor | rush not awarded before day 1,440 | Too early: raise `copy_surcharge` by 0.005 (economy.json) |
| Balanced award, easy / normal / hard | 1,800–2,520 / 2,160–2,880 / 2,520–3,240 | Late: loosen money (below); early: tighten |
| Cash cover before the award | median ≤ 60 days, p90 ≤ 120 | Too high = money too loose: `copy_surcharge` +0.005 (cap 0.04), or `admin_resident_scale` −250 (not below 1,500) |
| Cash cover after the award | median ≤ 180, p90 ≤ 365 | Same as above |
| Takeovers (rush, balanced, research-first) | as few as 1.8.0; report counts by difficulty | Up = too tight: `copy_surcharge` −0.005, `admin_settlement_growth` −0.05, or heavy mine `maintenance` back toward the 1.8 values (14 / 18 / 24) |
| Absorption | ≥ 80% of operating surplus in years 3–7 | Money piling up: report which sink is unused in the INFO rows below |
| Services budget | used by the balanced bot in ≥ 8 of 10 runs (this row is the 1.9 job's own) | Report only. Do not lower the bot's thresholds just to pass it |
| Openings | medians within 15%; best bot differs by opening | Missed in 1.8.0 too. Report; change only with a clear single cause |
| Labour lever | wage 1.0× → 1.3× moves year-2 arrivals ≥ 20% | Run `tests/balance/lever_probe.gd`; report |
| Payback (suite, not a row) | as in §4 | as in §4 |
| INFO: Spending by sink | none | Read it: where does the money go each year? |
| INFO: Windfall | none | With ¥1,000,000 on day 1,080, cover on day 1,440 should come back down within a year. If it stays above 360 days, the sinks are too weak: report |
| INFO: Late great works | none | A work standing in **no** run: first check whether its tech (`techs.json`) is ever researched. Not researched: raise its tech `weight` from 3–4 to 6. Researched but never built: lower its `cost` 20%. Still nobody after one more full run: **ask the user** before dropping it |

Every value you change goes into DECISIONS with the before and after numbers of the rows it moved.

## 8. Record

- `docs/v17/BALANCE.md`: written by the harness; add one sentence under "1.9 money" naming the full
  run.
- `docs/v17/PROGRESS.md`, 1.9 section: add a "Windows" table with one row per step here (result,
  evidence label, file), replace open items 1 and 2 with what is still open, and update the test
  results.
- `docs/v17/DECISIONS.md`: one line per value or rule you changed.
- `CHANGELOG.md`: only for changes a player would notice.
- Commit each step on its own (explicit paths), push `v17`.

## 9. Report to the user

A short table, one row per section above: done / MISS / blocked, the evidence label, and the file to
look at. Then the harness rows that missed with their numbers, the frame-time table, anything you
changed and why, and anything you need the user to decide. Say plainly what did not pass.
