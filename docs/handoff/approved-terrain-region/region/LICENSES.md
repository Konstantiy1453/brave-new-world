# Regional preview asset credits

The standalone Godot reference includes 71 runtime media files. [ASSET_MANIFEST.json](ASSET_MANIFEST.json) lists their sizes and SHA-256 digests, the source FBX names for the buildings and vehicles, and the downloaded-file checksums for the four scanned rocks. Manifest paths start at this reference project.

## Scanned rocks

Poly Haven distributes the following four models and their surface maps under the CC0 1.0 Universal dedication. The reference includes derived geometry, color-graded albedo, tangent-space normal maps, and packed ambient-occlusion, roughness and metalness maps. The source pages credit the following artists. [Poly Haven asset license](https://polyhaven.com/license) · [CC0 dedication](https://creativecommons.org/publicdomain/zero/1.0/)

| Source model | Artist credits | Files |
| --- | --- | --- |
| [Boulder 01](https://polyhaven.com/a/boulder_01) | Rico Cilliers | `assets/surface07/rock_assets/boulder_01/` |
| [Namaqualand Boulder 04](https://polyhaven.com/a/namaqualand_boulder_04) | Jenelle van Heerden | `assets/surface07/rock_assets/namaqualand_boulder_04/` |
| [Namaqualand Boulder 05](https://polyhaven.com/a/namaqualand_boulder_05) | Photography by Dario Barresi, modeling by Jenelle van Heerden | `assets/surface07/rock_assets/namaqualand_boulder_05/` |
| [Namaqualand Boulder 06](https://polyhaven.com/a/namaqualand_boulder_06) | Photography by Greg Zaal, modeling by Jenelle van Heerden | `assets/surface07/rock_assets/namaqualand_boulder_06/` |

The approved revision uses three identical 56,540-triangle files for Boulder 01 at close, middle and chip distances. The other three rocks use approximately 14,000, 2,000 and 220 triangles respectively. Keep the approved close-up for visual comparison, build real lower-detail versions of Boulder 01 for gameplay, and measure frame time with a populated region. Small chips are numerous. Check them both at ground level and from the district overview.

## Colony Charter artwork

The settlement meshes come from the project's 3ds Max high-poly art reserve. This reference includes the 14 building types and 3 vehicle types used in the approved view. Five extra meshes crop the original site platforms while preserving building dimensions and pivots. The loaders use the original resources to establish placement, then apply the cropped meshes to the five affected models. The manifest records the source-art archive names for provenance. The reference already includes the converted resources.

Project-authored environment meshes provide tree trunks, foliage, shrubs, distant grass, and exposed hillside rocks. The retained soil and rock base colors are derived from the project's seeded procedural surface tiles. The leaf atlas, procedural masks, ground-cover textures, road-shoulder raster and fixed vegetation placement data were prepared for these project previews. Keep these assets under the project's existing artwork terms. The four Poly Haven asset families above have their own CC0 dedication.

The road-shoulder mask covers the approved layout and is aligned to the physical road meshes. Regenerate it when adapting the appearance to another generated settlement.
