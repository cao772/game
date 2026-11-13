# Modern residential street source candidate

The regional explorer now offers a separate modern residential street. Entering first saves the existing `world_free` state. Returning reconstructs that saved world; the new street does not modify the old atlas, save schema, resident routes or quest contracts. Street position is temporary.

The street has an independent foot-origin controller: first person by default, V for a close shoulder camera, held RMB for look, WASD movement, Shift run and Space jump. Eye height is 1.68 m, walk speed 2 m/s, run speed 4.8 m/s. The shoulder camera uses a collision-tested 2.2 m rear distance and 0.35 m lateral offset. Window focus loss, GUI keyboard focus and disabled controls stop movement and release the pointer.

Four six-storey blocks enclose a main street with a central cross-alley and rear paths. The street includes shopfronts, balconies, security grilles, air-conditioning units, drainpipes, trees and static street props. Its generated geometry is a scale/material study, not photogrammetry or a completed realistic city. Doors and vehicles are static; there are no playable interiors, driving or autonomous urban residents.

## Included material assets

Nine unmodified 1K JPEG maps are bundled under `game/art/urban_materials`: diffuse, roughness and OpenGL normal maps for each material. `SOURCE.json` pins download URLs, upstream MD5, byte counts and local SHA256. The alias `concrete` refers to grey wall plaster.

| Local alias | Asset | Author | Physical repeat |
|---|---|---|---|
| concrete | [Grey Plaster 02](https://polyhaven.com/a/grey_plaster_02) | Rob Tuytel | 1 m |
| asphalt | [Asphalt 02](https://polyhaven.com/a/asphalt_02) | Rob Tuytel | 3 m |
| paving | [Concrete Pavement](https://polyhaven.com/a/concrete_pavement) | Charlotte Baglioni | 1.8 m |

The source assets are [CC0](https://polyhaven.com/license). No third-party reference photographs are bundled as game textures. Architecture and signs are generic original combinations.

## Entry and preservation

- Public entry remains `res://scenes/world_explorer.tscn`.
- New entry: `res://scenes/modern_street.tscn`.
- `world_explorer.modern_scene` and `modern_street.return_scene_path` use exported file paths so inherited private scenes can preserve their own return target without circular PackedScene preloads.
- Save failure prevents leaving the old world. Scene-change failure is shown in the current scene.
- Modern camera and geometry are isolated from the existing world controller.

## Verification boundary

This milestone is source authored and statically reviewed only. Offline GDScript grammar parsing, resource resolution, texture signatures/hashes and old content preservation are checked. These checks do not constitute Godot import/type-checking, gameplay tests, camera/collision acceptance, rendered visual approval or performance measurement. Engine, game, tests and Windows build remain NOT_RUN.

When runtime execution is authorized, acceptance should cover a full street/alley/rear-path loop, first/third camera switching beside walls, pointer release and UI input, focus loss during jumping, save-before-entry and return restoration. Close-range art still needs detailed meshes, decals, final characters, lighting and sound.
