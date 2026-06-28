# CraftDomain - Development Roadmap & Milestone Tracker

This roadmap documents the architectural milestones, optimization phases, and gameplay expansions of the CraftDomain voxel sandbox engine. It tracks completed features and outlines the short-term, mid-term, and long-term goals of the project.

---

## 🗺️ Progress Dashboard

| Milestone | Phase Title | Status | Target / Release |
| :--- | :--- | :---: | :--- |
| **Milestone 1** | Core Voxel & Procedural World | **COMPLETED** | Release v1.0.0 |
| **Milestone 2** | SOLID Infrastructure & Decoupled UI | **COMPLETED** | Release v1.1.0 |
| **Milestone 3** | Minecraft HUD, 24-Slot Inventory & Crafting | **COMPLETED** | Release v1.2.0 (Current) |
| **Milestone 4** | Spatial & Foley Audio Engine | *IN PROGRESS* | Target v1.3.0 |
| **Milestone 5** | Greedy Meshing & Chunk Compression | *PLANNED* | Target v1.4.0 |
| **Milestone 6** | Extended Sandbox Mechanics & Farming | *PLANNED* | Target v1.5.0 |
| **Milestone 7** | Client-Server Headless Multiplayer | *LONG-TERM* | Target v2.0.0 |

---

## 🟢 Completed Milestones

### Milestone 1: Core Voxel & Procedural World (v1.0.0)
*   **Infinite Vertical Grid:** Created an optimized 3D chunk loader loading vertical layers $Y=0$ and $Y=1$ (height range 0 to 31) to prevent rendering clipping and support high-altitude building.
*   **Procedural Biomes:** Implemented `IBiome` strategy patterns to define 10 geographically distinct regions (Bay of Sails, Warp Plateau, Golden Bazaar, Craggy Peaks, etc.).
*   **Weather-Integrated GPU Shader:** Developed a custom sky dome shader processing astronomical sun/moon orbits, twinkling stars, and dynamic overcast fades (0.0 to 1.0) during rain/snow transitions.
*   **Regional Precipitation:** Positioned wind-blown snowflakes above the player's head inside glaciers, and fast-falling translucent rain needles in temperate biomes.

### Milestone 2: SOLID Infrastructure & Decoupled UI (v1.1.0)
*   **Asynchronous Thread Pool:** Offloaded chunk procedurals and JSON loading modification deltas to background threads via Godot's `WorkerThreadPool` to prevent main-thread physics stuttering.
*   **Stateless Meshing (SRP):** Extracted 3D MultiMesh and physics collider generation out of the `WorldController` into the stateless helper `ChunkVisualBuilder`.
*   **Dynamic Mob Spawner (OCP):** Created `MobRegistry` to register entity factory Callables at boot time, decoupling custom wildlife and NPC instantiation from the spawning loop.
*   **Zero-Warning Strict Typing:** Refactored dynamic script loading (`load().new()`) to clean global class instantiations, clearing all `UNSAFE_CAST` and `UNSAFE_CALL_ARGUMENT` parser warnings.

### Milestone 3: Minecraft HUD, 24-Slot Inventory & Crafting (v1.2.0 - Current)
*   **Minecraft Responsive HUD Layout:**
	*   Designed a unified, center-bottom docked Hotbar container.
	*   Positioned detailed Red Hearts (`❤`) directly above the Hotbar left corner.
	*   Positioned Fried Chicken drumsticks (`🍗`) directly above the Hotbar right corner.
	*   Docked clickable Backpack (`🎒 [I]`) and Workshop (`🛠️ [C]`) shortcut buttons to the sides for ergonomic mouse play.
	*   Applied 3D inner shaded relief borders to all HUD block icons.
*   **Stack-Based 24-Slot Grid Inventory:**
	*   Partitioned inventory into 8 Hotbar slots and 16 Backpack storage slots.
	*   Implemented items stacking (up to 64 units) and OCP-compliant dynamic block pickup routing.
	*   Created the **Sequential Swapping Engine** allowing players to click Slot A and then Slot B to physically rearrange items in the grids.
	*   Built an Item Inspector displaying detailed specs, stock counts, usage descriptions, and direct Use/Eat actions.
*   **Context-Aware Crafting Workshop:**
	*   Designed a dual-pane workshop parsing 12 dynamic recipes from `recipes.json`.
	*   Implemented an ingredients checklist displaying green (`✔`) or red (`✘`) checkmarks based on total inventory counts.
	*   Wired the fabrication pipeline to deduct inputs globally across the grid, add the output to empty/stackable slots, and trigger viewmodel hand-swings.

---

## 🟡 Short-Term Goals (In Progress)

### Milestone 4: Spatial & Foley Audio Engine (v1.3.0)
*   [ ] **Block-Dependent Footstep Foley:** Wire `PlayerController` to run quick vertical raycasts down to the ground. Play unique step sounds (`AudioStreamPlayer3D`) depending on the surface material (e.g., resonance on Stone, grass rumbles on Turf, hollow thuds on Wood).
*   [ ] **Spatial Environmental Audio:**
	*   Assign spatial audio streams to active mobs (bellowing cows, oinking pigs, chicken clucks, zombie groans).
	*   Attach spatial 3D wind soundscapes to mountain ranges and rustling leaf sounds inside forest biomes.
*   [ ] **Action Feedback sounds:** Add muffled impacts when mining blocks, metallic hits when attacking zombies, paper ruffles when opening menus, and eating gulps when consuming fried chicken.

---

## 🔵 Mid-Term Goals (Planned)

### Milestone 5: Greedy Meshing & Chunk Compression (v1.4.0)
*   [ ] **Greedy Meshing Implementation:** Upgrade the chunk renderer. Instead of instantiating individual 1x1x1 boxes inside the MultiMesh, implement a greedy-meshing compiler that merges adjacent, identical block faces into larger, singular rectangular prisms. This will reduce GPU vertex count in dense regions by up to 80% and optimize memory allocation.
*   [ ] **Run-Length Encoding (RLE) Delta Saving:** Compress modified block dictionaries written to disk (e.g. `chunk_0_0_0.json`) using RLE compression, minimizing file size and directory footprint during massive, long-term construction sessions.

### Milestone 6: Extended Sandbox Mechanics & Farming (v1.5.0)
*   [ ] **Agricultural Growth Ticks:**
	*   Add wheat/crop seeds as collectable foliage drops.
	*   Implement plant growth stages (Seed ➔ Sprout ➔ Ripe) triggered by random chunk ticks.
	*   Utilize the Guard/Farmer NPC AI task loops to dynamically harvest ripe crops.
*   [ ] **Interactive Voxel Wiring (Neon Signals):** Use `NEON_CYAN` and `NEON_MAGENTA` blocks as logical signals (comparable to redstone wire). Powering a neon pathway can trigger dynamic actions, such as sliding open glass cabin doors or activating streetlights.

---

## 🟣 Long-Term Vision (Future Milestones)

### Milestone 7: Client-Server Headless Multiplayer (v2.0.0)
*   **Headless Server Compilation:** Since CraftDomain uses strict Domain-Driven Design (DDD) where `WorldState` and `VoxelEntity` contain pure logical rules with zero engine node dependencies, compile a Headless Server build that runs the game logic blindly on Linux servers.
*   **Godot RPC Synchronization:**
	*   Wire player movements, block edits, and crafting transactions to synchronize over network sockets using Godot's High-Level Multiplayer API.
    *   Implement server-authoritative coordinate checks to prevent physics clipping.
    *   Ensure thread-safe chunk data streaming to clients as they navigate the infinite procedural coordinate grid.
