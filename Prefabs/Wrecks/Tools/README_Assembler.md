# Spotlight Target Assembler

## Getting Far mesh and Collision (shape) to fill

- **Far / Mid / Near**: If a .glb uses the same node names with an `X_X_X` suffix (e.g. `Chunk_0_0_0`), the assembler matches by name. If Far (or any LOD) uses different names, the assembler falls back to **order**: it assumes the same number of meshes in the same tree order as Near, so Far mesh at position 0 matches Near at position 0, etc.

- **Collisions.glb**: To get `CollisionShape3D` nodes (so each chunk has a shape for climbable/spotlight):

  1. **Option A – Advanced Import**  
	 Select `Big_Dawg_Collisions.glb` → **Advanced…** → Scene tab. For each mesh node, enable **Generate > Physics**. Set **Physics > Shape Type** to **Trimesh** for static wreck geometry. Reimport.

  2. **Option B – Name suffix**  
	 In your 3D app, name collision meshes with a suffix Godot understands, then re-export:
	 - `-colonly`: mesh is removed, replaced by a `StaticBody3D` + `CollisionShape3D` (good for collision-only proxies).
	 - `-col`: same mesh stays; a child `CollisionShape3D` is added.

  Ensure **Nodes > Use Node Type Suffixes** is enabled in the Collisions .import (it is by default).

After reimporting Collisions with one of the options above, run the assembler again (check **Run** on the BigDawgAssembler root).
