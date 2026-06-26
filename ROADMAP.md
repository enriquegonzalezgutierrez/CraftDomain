# CraftDomain - Voxel Engine Development Roadmap

This document outlines the completed engineering milestones and the progressive future roadmap for **CraftDomain**, keeping development strictly aligned with **SOLID software engineering principles** and **Domain-Driven Design (DDD)** constraints.

---

## Phase 1: Voxel Engine Core & High-End Visuals (Completed)

Focus was placed on optimizing Godot's Vulkan Forward+ rendering pipeline, implementing modular shader calculations, and structuring the base game loop.

- [x] **Composition Root Bootloader:** Created `Bootstrap.gd` to handle dynamic dependency injection, environment setups, and clean transitions, eliminating circular compiler loops.
- [x] **SOLID UI Widget Refactoring:** Decoupled `PlayerHUD.gd` from a monolithic class into independent, single-responsibility widgets (`MinimapWidget.gd`, `GPSPanelWidget.gd`, `QuestTrackerWidget.gd`), implementing the Facade/Adapter pattern.
- [x] **Next-Gen PBR Voxel Shading:** 
  - Segmented chunk rendering into per-block MultiMeshes to allow transparent water meshes and emissive lava.
  - Implemented a custom GPU Voxel Triplanar Shader to prevent texture stretching on cubes and automatically blend custom texture alpha channels with procedural base colors (resolving black-pixel artifacts).
  - Programmed a custom GPU Vertex Foliage Shader for leaf blocks, adding natural wind-waving lateral sways and organic rounded fluffiness to breaking box shapes.
- [x] **Static Texture Preloader:** Implemented a thread-safe static loader in `ChunkNode.gd` that caches 1024x1024 custom block assets on game boot, completely eliminating main-thread disk I/O lag and preventing physics tunneling.
- [x] **Celestial & Climatological Simulation:**
  - Implemented a dynamic 28-day Lunar Cycle in `CelestialService.gd` with silver-blue shadow-casting moonlight that scales according to moon phases.
  - Created a decoupled, regional `WeatherService.gd` that emits fast-falling rain needles over temperate biomes, but dynamically shifts to fluffy, wind-blown white snowflakes over the polar ice caps or cloud kingdoms.

---

## Phase 2: Sandbox Expansion & Survival Mechanics (Short-Term)

Focus is on enriching the survival game loop, adding physics variables, and expanding sandbox interactions.

- [ ] **Cellular-Automata Fluid Physics:**
  - Implement a lightweight, decoupled `FluidSimulationService.gd` in the domain layer.
  - Process placed water and lava blocks, calculating finite-state spreading and downward flow physics in the voxel grid.
- [ ] **Dynamic Structure Spawning (OCP/DIP compliant):**
  - Create a generic structure schematic reader (`res://assets/schematics/`) that parses custom voxel designs from disk and writes them dynamically to chunk matrices.
  - Allows adding custom buildings, bridges, and dungeons without modifying the `WorldGenerator` logic.
- [ ] **Player Survival Attributes (DDD Aggregates):**
  - Refactor `VoxelEntity.gd` to manage hunger, stamina, oxygen, and fall damage variables in the domain layer.
  - Integrate a drowning timer inside `VoxelInteractionComponent.gd` when the player's eye-level camera dips below the water mesh height.

---

## Phase 3: Multiplayer & High-Refresh Optimizations (Mid-Term)

Focus is on network replication, multi-threaded performance, and memory footprints during infinite travel.

- [ ] **C++ GDExtension Voxel Meshing:**
  - Migrate the heavy coordinate-looping voxel face-culling and bulk array compiler from GDScript to a C++ GDExtension module.
  - Eliminates garbage collection spikes during high-speed camera travel.
- [ ] **Network Replication Layer (DIP/ISP compliant):**
  - Implement real-time multi-player state synchronization using Godot's high-level multiplayer API.
  - Keep packet overhead low by only synchronizing block edit deltas (`WorldState._chunk_modifications`) across clients.
- [ ] **Save State Compression:**
  - Compress JSON delta-chunk files (`chunk_x_y_z.json`) on disk using GZip or Brotli compression to minimize storage footprints for massive, infinitely explored worlds.

---

## Phase 4: Creative Tools & Advanced AI (Long-Term)

Focus is on user-generated content, in-game editors, and complex agent behaviors.

- [ ] **In-Game Visual Quest Designer (OCP compliant):**
  - Implement an in-game graphical node interface (Quest Creator) that allows players to design custom quest chains, coordinate targets, and rewards.
  - Outputs directly as validated JSON files inside `res://assets/quests/`, instantly loaded by the engine at runtime without rebuilding.
- [ ] **Dynamic Pathfinding (A* on Voxel Meshes):**
  - Implement a 3D A* pathfinding algorithm (`AStar3D`) inside `MobSpawningService.gd`.
  - Allows guards, merchants, and hostile entities to navigate irregular voxel terrain, climb stairs, and bypass player-built walls intelligently.
