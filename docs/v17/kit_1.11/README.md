# Windows run kit, pre-checked on Linux (1.11.0, 2026-11-24)

The kit's cases (`tools/windows_run_kit.ps1`) run against the shipped PCK with the Linux build of the same
engine (`--main-pack`, xvfb, software OpenGL). Evidence: exported PCK on the Linux runtime; the Windows EXE
itself was not started (no Windows machine in the cloud session).

| | |
|---|---|
| PCK | `build/v17/ColonyCharter.pck` from `741b872`, SHA-256 `7CAB83CCE520458E68ED1FE1717A5FACC94C3C5520F3AAE73C205FFCE3E7A31D` |
| Engine | Godot 4.5.1-stable, Linux x86_64 |

| Case | Checks | Result |
|---|---:|---|
| `cap_globe` | 14 | pass (`cap_globe.json`) |
| `cap_flat` | 14 | pass |
| `regression` | 16 | pass |
| `refusal` | 7 | pass |
| `out_inland_globe` | 22 | pass |
| `out_coast_flat` | 22 | pass |
| `save_carry` (a 1.10.0 save in 1.11.0) | 13 | pass |
| `boot` (3,000 frames) | - | not finished: software rendering ran past the 600-second limit; no `SCRIPT ERROR` in its log |

108 of 108 checks in seven cases. Two kit changes came first: the placement driver scrolls a page taller
than the window before it clicks (the 1.11 menu's contract cards push its last buttons below 720 pixels),
and the kit copies `contract_play.gd` with the bots (1.11's colony bot loads it). The only engine error
line in every log is the container's missing sound device (ALSA, then Godot's dummy audio driver).
