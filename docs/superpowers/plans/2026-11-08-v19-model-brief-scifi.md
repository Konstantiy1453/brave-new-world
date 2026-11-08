# Colony Charter — model brief for the 3ds Max agent: near-future colony look, the shuttle, vehicles and the missing models

This is the brief for the modelling agent (the user pastes it to Codex, as with the 1.9 plan's §C2 brief,
which still holds for everything this brief does not change). It sets one art direction for every new model,
adds the short-range shuttle and the road vehicles, and lists what is still missing in priority order.

## 1. Art direction: grounded near-future colony

Colony Charter is a 22nd-century colony on a frontier planet run under a company charter: orbital lift
port, landing pods, fusion and fission plants, atmosphere processors, terraforming. Most of the delivered
models read as present-day industry. New models should read as **the colony's own technology, a hundred
years on, built from prefabricated kits shipped from orbit**. Not space opera.

| Do | Don't |
|---|---|
| Pressurised modules: capsules, cylinders and domes with ribbed frames, joined by short sealed corridors | Floating shapes, organic alien forms, crystal cathedrals |
| Prefab kit logic: repeated panels with chamfered edges, the same module family across buildings | One-off ornament, gothic or art-deco detailing |
| Airlocks with frames, docking clamps, hatches, landing pads with edge markings and lights | Neon everywhere, holograms, text, logos, flags |
| Heat: radiator fins and heat-exchanger panels on plants, mines and data centres | Thin greebles as the main shape (they vanish, see below) |
| Tanks, pipe runs, antenna masts and dishes, solar wings, dust skirts on vehicles | Weapons, military vehicles |
| One **hero feature** per building that names it from 50° above: the hospital's dome, the smelter's furnace stack with radiators, the vat farm's row of glass tubes | Buildings that differ only in size |

**It has to read at diorama scale.** In the game a building is a piece about 4 units wide seen from 40–60°
above, about 60 px on screen. The converter drops parts smaller than about 1.2 m and decimates to ~4,500
triangles (great works 9,000). Sci-fi comes from silhouette and big masses, with fine detail as accent only.
Test: shrink the hero render to 64 px; if you cannot tell what it is, simplify.

**Colour comes from part names.** The game recolours every part by the words in its node name; textures are
optional. Keep the existing palette roles (§3) and give each building one strong accent area (`warning` /
`chevron` / `safety_band`) and one glazed area (`glass`). Name lights `status_light`: the game draws them as panels today and will light them later.

**One family.** New models must sit next to the accepted ones. The eight older generic models (§4, P3) are
remade in this language last, so the town does not mix two eras.

## 2. Technical rules (unchanged from the 1.9 plan §C2)

- Deliver into `art_reserve/max_models_<date>/` with the layout of `max_highpoly_20261031`: MAX, FBX in
  `08_exports/highpoly_fbx`, per-asset metadata JSON in `10_validation/` (`measured_size`, `bounds`, `axis`,
  `doors`, `geometry.nodes` with names and bounds), hero renders with a 1.80 m figure (render only, not in the
  export), and `DELIVERY_TARGET_IDS.json` mapping each game id below to its FBX. Publish as a release zip
  `art-assets-<yyyymmdd>` as before. Never touch the game folders or the existing library.
- Metres, Z-up, front facing −Y, pivot at the footprint centre at grade. Footprint at most 45 × 45 m; great
  works at most 60 × 60 m; vehicles as given below.
- Name every part `CC_<KIT>_<part>_<nnnn>`, using the slot words in §3.
- Buildings also export `<ID>_CONSTRUCTION.fbx`: foundation, part-built frame, scaffold (a crane only for
  great works).
- Nothing tied to a world: no terrain, no planet, nothing seed-dependent.
- Keep it simplifiable. The converter reduces closed, connected shapes well; it cannot reduce open
  strips or one huge mesh. Model crop rows as a few closed low boxes or wide strips (at most 60
  triangles a row), tree crowns as closed low-poly shapes (at most 80), and pit terraces as a stepped
  low-poly mesh (at most 3,000). Today the field station, vertical farm, ranch and arcology (open crop
  and leaf strips) and the heavy open-pit mines (terraces of 378,000 triangles) stay over budget for
  this reason; the game's art suite lists them as exceptions until they are remade.

## 3. Slot words (the converter's colour rules)

| Slot (game colour) | Words in the part name |
|---|---|
| glass | `glass`, `glazing`, `transparent`, `lens`, `lantern` |
| shell (light panels) | anything no rule below matches, for example `wall`, `facade`, `cladding` |
| dark (machinery) | `vessel` (name tanks `vessel`), `panel`, `battery`, `container`, `cabinet`, `dish`, `transformer` |
| metal (structure) | `column`, `beam`, `frame`, `post`, `leg`, `rail`, `tower`, `girder` |
| gold (accents, safety) | `warning`, `chevron`, `safety_band`, `bollard`, `gantry`, `crane`, `_run`, `_elbow` |
| concrete | `foundation`, `slab`, `_pad`, `plinth`, `apron`, `landing`, `paving`, `ramp` |
| roof | `roof` |
| green | `crop`, `leaf`, `shrub`, `tree_canopy`, `grass`, `soil` |
| ore | `ore_stockpile`, `boulder`, `exposed_vein`, `crystal_hexagonal` |
| water | `water_surface`, `pond_water`, `pool_water` |

## 4. What to build, in order

Game ids are what `DELIVERY_TARGET_IDS.json` maps to; the game draws a stand-in until each arrives.

### P0 — the shuttle and the road vehicles (new in 1.9; the game already looks for these ids)

| Game id | What | Size | Triangles after conversion | Notes |
|---|---|---|---|---|
| `shuttle` | **Short-range cargo shuttle**: VTOL, 4–6 t of cargo, a lifting body or boxy hull with two or four ducted lift fans or thruster pods, a cockpit window band, a rear cargo ramp or side cargo door, landing legs | 14–18 m long, 8–12 m across | ~2,500 | Seen parked on its pad and in flight from above. Hero features: the lift fans and the cargo door. Export one model with legs down; a second `SHUTTLE_FLIGHT` with legs up is welcome |
| `shuttle_pad` | **Landing pad** (the game draws a plain disc until then): round or hexagonal deck with edge lights (`status_light`), a painted touchdown ring (`warning`), a small control kiosk, a fuel or charging post, a cargo handling cart | 16–20 m across | ~1,500 | Low and flat: the shuttle sits on it. The game places it on clear ground at the edge of town |
| `vehicle_truck` | Sealed-cab ore and cargo hauler, 6 or 8 big wheels, a dust skirt, a load bed with a cargo pod or ore heap | ~10 m long | 800–1,200 | Trucks run between mines, factories and route gates |
| `vehicle_van` | Crew and utility van, sealed cabin, roof equipment rack | ~6 m long | 600–900 | |
| `vehicle_bus` | Pressurised crew bus, long cabin with a window band and an airlock door | ~12 m long | 800–1,200 | |

Vehicles: pivot at the centre of the wheelbase at ground level, front facing −Y, no construction export.

### P1 — the sixteen building kinds that still borrow another model

| Game id | Building | Hero feature, in the near-future language |
|---|---|---|
| `mine_copper` | 轻型铜矿场 light copper mine | Compact headframe in a pressurised shed, green-tinted ore heap, conveyor to a hopper |
| `mine_crystal` | 晶体采掘站 crystal mine | Shaft head with a sealed hoist house and a crystal sorting hall with a glazed roof strip |
| `tailings_plant` | 尾矿回收站 tailings recovery | Big slurry tanks and a settling pond (`pond_water`) with a recovery crane |
| `sea_copper` | 海水提铜站 sea copper extraction | Offshore-style intake on legs, membrane stacks, brine tanks; stands at the shore |
| `crystal_vat` | 晶体培育槽 crystal vat farm | A row of tall glass growth tubes (`glass`) in a frame, with a control hall |
| `deep_well` | 深层水井 deep well | Drilling derrick capped with a pump house and a pressure tank |
| `atmospheric_water` | 大气集水站 atmospheric water | Condenser towers with radiator fins and a storage tank |
| `hydroponic_farm` | 水培温室 hydroponic greenhouse | Long pressurised glass vaults with lit racks (`crop` inside) |
| `protein_plant` | 合成蛋白厂 synthetic protein | Fermentation vessels in a hall, a cold store, clean steel |
| `foodworks` | 食品出口加工坊 food export works | Packing hall with a loading dock and sealed cargo containers |
| `smelter` | 合金冶炼厂 alloy smelter | Furnace hall with a tall stack and big radiator panels |
| `machine_works` | 精密机械厂 precision machine works | Clean-room hall, saw-tooth roof with glazing, an overhead crane outside |
| `pharma_plant` | 生物制药厂 pharma plant | White modular labs with a sterile dome and gas tanks |
| `institute` | 研究院 research institute | Campus of linked modules around a big observatory or antenna dish |
| `park` | 生态公园 eco park | A domed garden (`glass` dome over `tree_canopy`) with paths and a pond |
| `commerce` | 商业街区 commerce block | Covered arcade of shop modules under a long glazed canopy, signage boxes (no text) |

Also, if time allows: `service` (民营经营场地, the private enterprise's site), a modest mixed workshop and
office module; today it reuses the civic hall.

### P1 — the five late great works (stand-ins today; 60 × 60 m, ~9,000 triangles)

| Game id | Great work | What it should be |
|---|---|---|
| `terraforming` | 行星改造计划 terraforming programme | An atmosphere processor complex: tall stacks breathing vapour, a ring of radiators. Three stages (大气调和 / 水循环 / 土壤培育): one base plus two add-on sets in part groups named `_stage2` and `_stage3`, so the game can show each stage as it is finished (the game side adds that when the model arrives) |
| `capital_district` | 首府新区 capital district | A new quarter of mid-rise pressurised towers around a plaza; five levels: export the full district with the parts of each level in groups named `_level2` … `_level5`, so the game can grow it level by level (added on the game side when the model arrives) |
| `exchange` | 星际交易所 off-world exchange | A trading hall with a big dish array and an uplink tower |
| `shipyard` | 轨道船坞 orbital shipyard | Ground side of the yard: an assembly hall, a launch cradle with a half-built hull, cranes |
| `emergency_net` | 行星应急网 emergency network | Response centre: hangar with rescue vehicles, a beacon mast, a helipad |

### P2 — finish the seven models used before their review (`wip`)

海水淡化厂 `desalination`, 裂变电站 `fission`, 地热电站 `geothermal`, 重型铁矿场 `mine_ore_heavy`,
重型铜矿场 `mine_copper_heavy`, 重型晶体矿井 `mine_crystal_heavy`, 轨道货运站 `port`. Bring them into the
direction above while finishing them (radiators, sealed cabs on the machinery, pad markings).

### P3 — remake the eight older generic models in the same language

温室农场 `farm`, 模块住区 `habitat`, 复合加工厂 `processor`, 区域物流中心 `depot`, 轻型铁矿场 `mine_ore`,
光伏储能站 `power`, 教学研究所 `lab`, 净水泵站 `water`. Keep each one's footprint and main volume (the game's
layouts are built around them); change the skin and details.

### Later

Upgrade add-ons for levels 2–3 (mines, habitat, lab, port, farm, processor); people (a few colonists in
suits, optional).

## 5. Handoff

When a pack is published, tell the user the release tag. The game side adds recipes for the new ids to
`game/tests/art/model_recipes.json` and runs `tests/art/convert_models.gd`; the shuttle, pad and vehicles then
replace their stand-ins with no other change.
