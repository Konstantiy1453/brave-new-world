# Interface pass: runtime screenshots

Evidence label: **source-project window** (Godot 4.5.1 Linux build, software OpenGL under Xvfb), captured by
`game/ui/capture_suite_ui19.gd` and `game/ui/capture_suite_v17.gd` from a midgame colony that
`tests/make_fixtures_v17.gd --out=<folder>` played on the same machine (seed 260129, balanced bot, day 900;
the tutorial shot is a new tutorial game). Not concept art; nothing here was drawn by hand. Converted
from PNG to WebP (quality 84); the 2560 × 1440 shots are scaled down to 1600 wide. Not yet seen on Windows
or a real GPU.

| File | What it shows |
|---|---|
| `build.webp` | Construction at 1600 × 900, 18 px text: catalogue, chosen facility (here one the rules refuse: no free deposit), ledger with the verdict |
| `build_ready.webp` | A facility that can be built: plot chooser, ✓ verdict, enabled main order |
| `build_filter.webp` | The 「加工」 category chip chosen |
| `build_focus.webp` | Keyboard focus ring on a catalogue row |
| `build_tooltip.webp` | The refusal tooltip on a disabled quick order |
| `build_1280x720_20px.webp` | Construction in a 1280 × 720 window at the largest text size (20 px) |
| `build_2560x1440_16px.webp` | Construction in a 2560 × 1440 window at the smallest text size (16 px) |
| `research.webp` | Research at 1600 × 900, 18 px text: four directions, active and available topics |
| `research_scrolled.webp` | Research scrolled to the commission switches and the reshuffle buttons |
| `research_after_switch.webp` | Research opened again after construction: no construction styling left behind |
| `research_1280x720_20px.webp`, `research_2560x1440_16px.webp` | Research at the extremes of window and text size |
| `economy_neutral.webp` | A neutral page with the shared styling only |
| `buildings.webp`, `manage.webp` | The facility list and production management in the industrial variant |
| `region_column.webp` | The facility column beside the map (industrial) and the navigation marking the map view |
| `tutorial_build.webp` | The tutorial coach outlining the quick order over the construction dialog |
| `menu.webp` | The main menu with the shared button roles |

Every capture size and text size also ran the suite's checks (panel inside the window, every action
scrolled into view inside its scroll area, keyboard focus, frame variant after switching): 34 captures,
52 checks, 0 failures.
