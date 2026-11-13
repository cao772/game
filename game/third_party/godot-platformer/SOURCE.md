# Godot 3D platformer movement adaptation

Source: [Godot Engine demo projects](https://github.com/godotengine/godot-demo-projects/blob/6ecf265637d66104fbfa83da4af956681313436e/3d/platformer/player/player.gd),
4.1 branch, pinned commit `6ecf265637d66104fbfa83da4af956681313436e`.
License: MIT; complete upstream notice in LICENSE.md.

`world/world_player.gd` adapts the camera-basis direction conversion, horizontal
projection and normalization. Keyboard polling replaces the demo's InputMap;
the SpringArm, focus handling, jump request and model wrapper are local code.
The demo's shooting, coin logic, scene, meshes, sounds and camera script are not
included. Source inspected only; no upstream or local gameplay was executed.
