# Walking merchant resident

Kay Lousberg created the original **KayKit Adventurers Character Pack 1.0**, used at commit `672074b73ba276876a19e8816ecdc5241817ab47`. The unmodified upstream CC0 notice is included as [LICENSE.txt](LICENSE.txt). This notice describes the KayKit content. No new third-party material was added.

The hooded body, russet work apron, ochre waist tape and patch pocket are retained unchanged from the project's existing market actor. The apron is project-authored geometry, not an upstream KayKit mesh. All weapons and the cape remain removed.

This derivative combines the existing reduced model with the original `Walking_A` animation. It keeps exactly `Idle`, `Walking_A`, `Interact` and `Cheer`, with the original 41-joint skin and embedded PNG. Unused accessors and buffer views are discarded, and identical binary view payloads are shared. Mesh indices, skin bindings, node transforms and animation samples are unchanged. The rig faces local **+Z**, its origin is at the feet, and the resident controller scales it by **0.84**. Walking is in place: the original root translation stays zero and hip X/Z displacement is negligible; world movement comes from the external projection.

## Provenance

- [Original Rogue_Hooded.glb](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/blob/672074b73ba276876a19e8816ecdc5241817ab47/addons/kaykit_character_pack_adventures/Characters/gltf/Rogue_Hooded.glb)
- [Upstream repository](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/tree/672074b73ba276876a19e8816ecdc5241817ab47)
- Existing project derivative: `../market_actor/merchant.glb`; SHA-256 `d2b90c42f34d7e10e83e423a3f1f7c07fd8425a6d3fa40eaef1301db36ddf864`.
- Original GLB: 3,597,652 bytes; SHA-256 `93e6e25213009952276d9cf34f5d96a243767334c66f280db0433ddfabb91545`.
- Resident GLB: **387,512 bytes**; SHA-256 `454446e95bebeb84523418ef7f9e4495ed2c9c830caa0366e65203248003b4f8`.

## Static inspection

Readback compared every retained body vertex attribute and index payload against the original GLB, all four clips' samples, interpolation and named channel targets against the original clips, the complete skin binding payload and joint mapping, and the embedded PNG. Existing derivative geometry and materials were also compared byte for byte, including the merchant apron where present. Node, mesh, accessor and image references and buffer bounds were checked. The license copy is byte-identical to the selected source notice.

The model contains 7 meshes, 549 accessors and 304 buffer views. Clip durations in seconds: Idle 1.066667, Walking_A 1.066667, Interact 1.300000, Cheer 1.666667.

**NOT_RUN:** Godot import, rendering, animation playback, collision behavior, game tests and builds. Static payload comparison does not establish final visual or movement quality.
