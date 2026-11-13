# Picture quality and terrain (2026-11-13): screenshots

Runtime captures from the source project in a real window (Linux, Godot 4.5.1, 1600 × 900, 18 px
text). Standard is Compatibility on software OpenGL; high is Forward+ on software Vulkan (lavapipe),
so they show the look, not the speed. Evidence: source-project window, screenshots viewed. Not run on
Windows or a real GPU; human playtest NOT_RUN.

| File | What it shows |
|---|---|
| `terrain_town.webp` | The coastal town before (terraces, walls, mesas) and after (natural ground, graded pads, a smooth shore) |
| `terrain_close.webp` | The same, close up |
| `inland_0.webp`, `inland_8.webp` | Inland sites before (sea in view) and after (land to the horizon) |
| `renderers_day.webp` | Standard against 高画质 (Forward+) by day: the same palette, softer shadows |
| `renderers_night.webp` | The same at night: painted pools of light against real lamp lights |
| `anti_aliasing_zoom.webp` | Edges at 2× zoom: no anti-aliasing, 4× multisampling, 4× with FXAA (left off), Forward+ 4× with SMAA |
| `settings_quality.webp` | Settings: 地图画面 with 空地块标记, 画质, 抗锯齿 |
| `research_notice.webp` | The notice when a technology is finished |
| `globe_after_landing.webp` | The globe after landing: only the colony's places are named |
