# Walking courier resident

Kay Lousberg created the original **KayKit Adventurers Character Pack 1.0**, used at commit `672074b73ba276876a19e8816ecdc5241817ab47`. The unmodified upstream CC0 notice is included as [LICENSE.txt](LICENSE.txt). This notice describes the KayKit content. No new third-party material was added.

The unhooded body is retained unchanged from the project's existing clerk model. All weapons and the cape remain removed.

This derivative combines the existing reduced model with the original `Walking_A` animation. It keeps exactly `Idle`, `Walking_A`, `Interact` and `Cheer`, with the original 41-joint skin and embedded PNG. Unused accessors and buffer views are discarded, and identical binary view payloads are shared. Mesh indices, skin bindings, node transforms and animation samples are unchanged. The rig faces local **+Z**, its origin is at the feet, and the resident controller scales it by **0.84**. Walking is in place: the original root translation stays zero and hip X/Z displacement is negligible; world movement comes from the external projection.

## Provenance

- [Original Rogue.glb](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/blob/672074b73ba276876a19e8816ecdc5241817ab47/addons/kaykit_character_pack_adventures/Characters/gltf/Rogue.glb)
- [Upstream repository](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/tree/672074b73ba276876a19e8816ecdc5241817ab47)
- Existing project derivative: `../records_actor/clerk.glb`; SHA-256 `fa136bb77ed7e14e189175baf444456f3c6a91bbf0d74821bec629fca03a4316`.
- Original GLB: 3,616,284 bytes; SHA-256 `e825437cd4d2ee9c1960b517a74a69101e33eb409ae7fa8cedc7134a998fbb7d`.
- Resident GLB: **401,640 bytes**; SHA-256 `cad185ac63538e523648c5091d6fccda12e0cf345a0106a30b9204c9048fd2a0`.

## Static inspection

Readback compared every retained body vertex attribute and index payload against the original GLB, all four clips' samples, interpolation and named channel targets against the original clips, the complete skin binding payload and joint mapping, and the embedded PNG. Existing derivative geometry and materials were also compared byte for byte, including the merchant apron where present. Node, mesh, accessor and image references and buffer bounds were checked. The license copy is byte-identical to the selected source notice.

The model contains 6 meshes, 537 accessors and 294 buffer views. Clip durations in seconds: Idle 1.066667, Walking_A 1.066667, Interact 1.300000, Cheer 1.666667.

**NOT_RUN:** Godot import, rendering, animation playback, collision behavior, game tests and builds. Static payload comparison does not establish final visual or movement quality.
