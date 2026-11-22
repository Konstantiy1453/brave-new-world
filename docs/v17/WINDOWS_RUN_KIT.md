# Windows run kit — Colony Charter 1.10.1 preview (2026-11-22)

This kit runs the packaged Windows build on your PC and checks it. The cloud session cannot run Windows.

- **Part A** is automated: one PowerShell command, about 30–60 minutes.
- **Part B** is a few minutes of looking at the game in its window.
- Send back the results ZIP that Part A prints, plus the Part B screenshots.

## What you need

| | |
|---|---|
| Windows | 10 or 11, x64, a GPU with OpenGL 3.3 (the game's default renderer) |
| PowerShell | Windows PowerShell 5.1 (built in) or PowerShell 7 |
| Repository | `D:\勇敢新世界` on branch `v17-bay`, at `d24c660` or later (`git pull`) |
| The build | `ColonyCharter-1.10.1-preview-20261122-metals-crews-Windows-x64.zip`, SHA-256 `E621BCFBD90733DAFC6CB24376747EA4C289058726FB1E246BD42CED3F0364BA` |
| Only for `-Engine` / `-Suites` | the repository's `tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe` |

Your saves are safe. Every game the kit starts writes its user data under `evidence\v17\windows_kit\<time>\userdata`, so nothing in `%APPDATA%\ColonyCharter` is read or written.

## Part A — automated (from the repository root)

```powershell
cd D:\勇敢新世界
git pull
powershell -ExecutionPolicy Bypass -File tools\windows_run_kit.ps1 -Zip "<folder>\ColonyCharter-1.10.1-preview-20261122-metals-crews-Windows-x64.zip" -Suites
```

What it does, in order:

- Checks the ZIP's SHA-256 and unpacks it into the kit folder.
- Runs eight cases, each with its own time limit, a log and a JSON record:

| Case | What it checks | Limit | Pass |
|---|---|---|---|
| `cap_globe` | Found the capital at a picked point on the globe; save, quit, reload, still there | 15 min | `CASE_PASS`, 14 checks |
| `cap_flat` | The same on the flat map (which now wraps east–west) | 15 min | `CASE_PASS`, 14 checks |
| `regression` | Seed 3: six clicks on unmarked land in both views select the ground under the pointer | 15 min | `CASE_PASS`, 16 checks |
| `refusal` | Sea, polar and steep ground: the reason shows, the button is off, nothing is founded | 15 min | `CASE_PASS`, 7 checks |
| `out_inland_globe` | Bot plays to the expansion licence; expedition to inland ground through the interface; save, reload | 60 min | `CASE_PASS`, 22 checks |
| `out_coast_flat` | The same to coastal ground on the flat map | 60 min | `CASE_PASS`, 22 checks |
| `save_carry` | A 1.10.0 save (`docs\v17\placement\save_files\before-1.10.0.save`) loads and plays on in this build | 15 min | `CASE_PASS`, 13 checks |
| `boot` | The game starts and closes itself after 3,000 frames | 10 min | `CASE_PASS`, no `SCRIPT ERROR` in its log |

- With `-Suites`, it also runs from the source project the checks that only run on Windows: `v17_saves`, `v18_systems`, `world_v16_seed` and `v17_tutorial`. On Linux these print `SKIP … recorded on Windows`. Pass: `RUNNER: 4 passed, 0 failed` in `suites.txt`, with no SKIP lines for those fixtures.
- Finally it packs every log and record into `evidence\v17\windows_kit\<time>\windows-kit-results-<time>.zip`. The last line printed, `SEND_BACK …`, gives the path.

A case **passes** only if all four hold:

- its JSON record says `ok: true`;
- none of its checks failed;
- its log has no `SCRIPT ERROR`;
- it finished within its limit.

`CASE_DIED` means it ran past its time limit. `CASE_FAIL … no record written` means the game ran but the driver never wrote its record.

**If every driver case ends `no record written`**, the release EXE probably won't run a driver script. Run again with the engine from the repository, which is the same engine with the same PCK:

```powershell
powershell -ExecutionPolicy Bypass -File tools\windows_run_kit.ps1 -Zip "<zip>" -Engine tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe
```

To repeat only some cases: `-Only cap_flat,refusal`.

## Part B — look at it (about 10 minutes, the real EXE in its window)

Start the game with isolated user data. Use the kit folder that Part A created:

```powershell
$env:APPDATA = "D:\勇敢新世界\evidence\v17\windows_kit\<time>\userdata"
& "D:\勇敢新世界\evidence\v17\windows_kit\<time>\game\ColonyCharter.exe"
```

| # | Do | Pass | Screenshot |
|---|---|---|---|
| B1 | New game, stay on the globe (球面总览) | Behind the planet: dark space, a galaxy band, faint nebulae and many small stars | `b1_globe.png` |
| B2 | Right-drag the globe through a full turn, slowly | At one angle a **large bright star** appears beside or behind the planet's edge. **On Linux this glare did not render; this is the check that decides whether it works.** | `b2_star.png` (or say "no star at any angle") |
| B3 | Flat map (地区 / 平铺地图), scroll out as far as it goes | The North and South Poles sit exactly on the top and bottom window edges; it zooms out no further | `b3_flat_out.png` |
| B4 | On the flat map, keep dragging east for two full turns | No edge. The map repeats seamlessly across 180°, with town markers on both sides | `b4_seam.png` |
| B5 | Found a capital, build something, Ctrl+S, quit, start again, Continue | It continues where you left it | — |
| B6 | Construction page (建设), crews panel (工程队) | Three standing-order buttons: 按下单顺序 / 道路与抢修优先 / 设施优先; the training price shown | `b6_crews.png` |

Take screenshots with Win+Shift+S and save them into the kit's `out` folder before zipping. You can also attach them separately.

## What to send back

1. `windows-kit-results-<time>.zip` (from the `SEND_BACK` line). It holds `SUMMARY.txt`, every case's `.log` and `.json`, `suites.txt`, and the game's own logs (`userdata_*.log`).
2. The Part B screenshots, with a one-line verdict per row (pass / fail / what you saw).
3. If anything died or failed, the text of `SUMMARY.txt` pasted into the chat is enough to start.

## Where the logs are

| What | Path |
|---|---|
| Summary | `evidence\v17\windows_kit\<time>\out\SUMMARY.txt` |
| Each case | `evidence\v17\windows_kit\<time>\out\<case>.log` and `<case>.json` |
| The game's own logs | `evidence\v17\windows_kit\<time>\out\userdata_*.log` |
| Windows-only checks | `evidence\v17\windows_kit\<time>\out\suites.txt`, `v17_saves.log`, `v18_systems.log`, `world_v16_seed.log`, `v17_tutorial.log` |
