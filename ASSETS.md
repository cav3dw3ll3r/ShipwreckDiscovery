# External Asset Manifest

Large asset payloads are stored outside the source repository. Keep this file updated whenever an asset package is added, renamed, replaced, or moved to the final external asset drive.

## Restore Rule

Restore each package to the same project-relative path shown below. The game can use the local files from disk, but Git should not track the binary payloads.

## Asset Packages

| Package | Restore Path | Contents | External Location | Version/Hash |
| --- | --- | --- | --- | --- |
| Wreck and environment meshes | `Meshes/` | Optimized and source 3D model files, including `.glb`, `.gltf`, `.fbx`, `.blend`, `.obj` | Pending | Pending |
| Texture and image payloads | `Images/` | Texture sources, image files, skyboxes, and other binary image payloads | Pending | Pending |
| Audio payloads | `Audio/` | Music, sound effects, voice, and other audio binaries | Pending | Pending |
| Video payloads | `Resources/Scannable/Wrecks/videos/` | Wreck scan and discovery video files such as `.ogv`, `.mp4`, and `.webm` | Pending | Pending |
| Prefab binary payloads | `Prefabs/` | Binary models or media stored beside reference `.tscn` prefabs | Pending | Pending |
| Packed/exported resources | project root and `Build/` | Generated `.pck`, `.apk`, `.aab`, `.zip`, and packaged export files | Pending | Pending |

## Source Repo Expectations

The source repository should keep reference files that describe how assets are used, including `.tscn`, `.tres`, `.gd`, `.import`, and `.uid` files. Binary payloads should remain local or be restored from the external asset location.

## Automatic Asset Checks

`assets.manifest.json` is tracked by Git and is the source of truth for the local asset checker. The manifest records each external binary asset's project-relative path, package, byte size, SHA-256 hash, and placeholder external location.

The `Asset Manifest Checker` editor plugin runs when the Godot editor opens. It reports:

- `missing`: a manifest file is not present locally.
- `changed`: a local file exists but its size or hash differs.
- `extra`: a local ignored asset exists but is not listed in the manifest.
- `ok`: a local file matches the manifest.

Use the Godot editor's `Project > Tools` menu actions:

- `Asset Manifest: Check Assets Now` to manually rescan local assets.
- `Asset Manifest: Refresh From Local Assets` after intentionally accepting the current local assets as the new source of truth.
- `Asset Manifest: Open Manifest` to inspect the tracked JSON file.

The plugin also writes a local close-time report to `.godot/asset_manifest_checker/last_report.json`. That report is ignored with the rest of `.godot/` and is shown on the next editor open if it contains issues.

Before connecting GitHub, verify:

- `git status` does not show generated cache/build folders as tracked source changes.
- No files over 100 MB are staged.
- Godot can open `project.godot` after assets are restored.
- The game still plays locally with the restored asset payloads.
