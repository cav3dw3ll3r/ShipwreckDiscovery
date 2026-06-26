# Shipwreck Discovery

Godot project for Shipwreck Discovery.

## Local Setup

1. Clone or open this repository in Godot 4.5 or newer.
2. Restore the external asset payloads listed in `ASSETS.md`.
3. Place each restored asset folder at its documented project-relative path.
4. Open `project.godot` and let Godot rebuild `.godot/` locally.

The source repository is intended to contain code, scenes, project settings, lightweight Godot resources, and reference-only prefabs. Large 3D models, textures, audio, generated imports, and builds are intentionally kept out of Git.

## Version Control Boundary

Tracked source/reference content includes:

- `project.godot`
- `Scripts/`
- `Scenes/`
- `Prefabs/**/*.tscn`
- `Resources/**/*.tres`
- `Materials/**/*.tres`
- `addons/`
- Godot text metadata such as `.uid`, `.import`, `.cfg`, and `.tres` files

External or generated content includes:

- `.godot/`
- `Build/`
- `android/build/`
- `Meshes/`
- `Audio/`
- `Images/`
- exported `.apk`, `.aab`, `.zip`, and `.pck` files
- binary model, texture, audio, and video files

## GitHub Setup

GitHub remote setup is intentionally deferred until the project is verified locally with restored assets. Before pushing, confirm that no generated folders or files over GitHub's 100 MB limit are staged.
