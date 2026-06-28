# CraftDomain - Engine Architecture, Graphics & Gameplay Roadmap

This document outlines the technical trajectory, architectural milestones, and planned features for the **CraftDomain** voxel sandbox engine. The roadmap is divided into iterative phases focusing on performance optimizations, SOLID design compliance, deep gameplay loops, and networking foundations.

---

## Phase 1: Voxel Core & Domain Foundation (Completed)
*Focus: Establish the DDD layer separation, basic chunk meshing, and infinite world coordination.*

*   [x] **Domain Model Isolation:** Encapsulate voxel chunk grids, logical blocks, and player states strictly within the Domain Layer (`src/Domain/`), keeping them completely free of Godot node dependencies.
*   [x] **Partitioned MultiMesh Mesher:** Implement a multi-mesh chunk mesher (`ChunkNode.gd`) to separate translucent fluid blocks (Water, Lava) from solid voxels to support specialized shaders and reflections.
*   [x] **Delta-Save Pipeline:** Create an asynchronous, stutter-free JSON serialization repository (`DiskWorldRepository.gd`) to save local voxel modifications to disk on thread buffers.
*   [x] **Composition Root:** Establish a clean application bootstrapper (`Bootstrap.gd`) to dynamically register biomes/structures and inject dependencies, preventing circular compiler loops.

---

## Phase 2: Atmospheric Rendering & Immersive Interface (Completed)
*Focus: Elevate environment realism, optimize rendering shaders, and streamline the player's on-screen interface.*

*   [x] **GPU-Optimized Procedural Sky Shader:** Move all celestial color gradients, Sun/Moon orbits, and FBM cloud projections to a dedicated GPU Sky Shader, eliminating CPU-bound color calculations.
*   [x] **Deterministic Orbit Synchronization:** Direct the physical Sun/Moon light vectors from `CelestialService.gd` directly to the shader uniforms, resolving light index swapping artifacts and matching sky states with the clock.
*   [x] **Meteorological Overcast Transitions:** Coordinate `WeatherService.gd` state changes (sunny, rainy, snowy) with the sky shader to smoothly interpolate cloud density, sky coloration, and sun dimming.
*   [x] **Minimalist Hotbar & Fading Toasts:** Redesign the HUD to shrink hotbar space, replace static text with procedural color-coded item blocks, and add a fading selected-item name notification to enhance game immersion.
*   [x] **Procedural NPC Rigging and Animations:** Implement the `_body_bob_node` walking joint on `PassiveEntity.gd` to simulate realistic footstep bouncing. Overhaul Villager, Merchant, Guard, and Farmer 3D programmatic models.

---

## Phase 3: Expanded Domain Economy & Inventory Systems (In-Progress)
*Focus: Expand the Domain Layer to support complex item manipulation, crafting matrices, and container tracking.*

*   [ ] **Full Grid Inventory UI (The "E" Menu):** Implement a full-screen inventory GUI overlay, allowing players to drag and drop items, manage storage, and organize blocks between their main backpack and the 8 quick-slots.
*   [ ] **Extensible Crafting Matrix Service:** Establish a decoupled `CraftingService` that reads recipe matrices from an external `recipes.json` configuration file, allowing players to combine items into tools.
*   [ ] **Persistent Container System:** Extend the `WorldState` aggregate to track and save the inventory states of individual physical props (such as chests) generated procedurally in the world.
*   [ ] **Economic Transactions Overhaul:** Refactor `TradingService` to support dynamic currency exchange (using copper/silver equivalents) instead of single-item direct barter.

---

## Phase 4: Advanced Generation, Cave Carvers & Multi-Threading (Planned)
*Focus: Optimize world generation and chunk loading performance to completely eliminate frame stuttering.*

*   [ ] **Strict OCP Landmark Registry:** Move the hardcoded landmark-to-blueprint mapping currently residing in `WorldGenerator.gd` into a dynamic, registration-based system within `StructureLibrary`.
*   [ ] **Multithreaded Mesh Compilation:** Offload the generation of `ArrayMesh` surfaces from the main thread to worker threads using Godot's `WorkerThreadPool`, eliminating rendering lag spikes when crossing chunk boundaries.
*   [ ] **Cave Carver Noise Service:** Add a 3D Simplex Noise service to carve hollow, subterranean tunnels and ore veins beneath the Craggy Peaks biome.
*   [ ] **Cellular Automata Fluids:** Implement a CPU-bound cellular automata fluid simulation to allow water and lava blocks to flow dynamically when adjacent blocks are mined.

---

## Phase 5: Combat Overhaul, Weapon Classes & Enemy AI (Planned)
*Focus: Deepen the combat mechanics, introduce ranged weaponry, and establish pathfinding algorithms for hostile mobs.*

*   [ ] **Ranged Weaponry Integration:** Introduce bows, projectiles (arrows), and throwables, separating projectile physics into an isolated infrastructure component.
*   [ ] **A\* Voxel Pathfinding Service:** Build a high-performance 3D A* pathfinding system that maps the local solid voxel grid, allowing zombies to navigate around walls and climb steps intelligently.
*   [ ] **Lunar Event Spawning Cycles:** Connect monster spawn rates and stats with the 28-day lunar phase tracked by `CelestialService.gd` (e.g., higher aggression and elite spawns during Full Moons).
*   [ ] **Entity Combat Stats:** Expand `VoxelEntity.gd` to encapsulate modular defense, knockback resistance, and attack damage attributes, separating stats calculations from physics nodes.

---

## Phase 6: Town Generation & Dynamic Structure Blueprints (Planned)
*Focus: Scale structure blueprints into multi-building, procedurally generated village settlements.*

*   [ ] **Procedural Town Planner:** Develop a village layout algorithm that scans flat coordinates in plains biomes, carves dirt roads, and spawns houses, market cabins, and streetlights deterministically.
*   [ ] **Connected Streetlight Power Grid:** Connect registered village streetlights to a local grid controller, letting them toggle on and off based on ambient power lines instead of polling the clock individually.
*   [ ] **Dynamic Structure Rotations:** Update `IStructureBlueprint` to support 90, 180, and 270-degree rotation matrices during generation, allowing buildings to face roads naturally.

---

## Phase 7: Modding API, Extensibility & Custom Blocks (Long-Term)
*Focus: Transform the engine into a highly moddable platform via data-driven registries.*

*   [ ] **Data-Driven Block Registry:** Refactor `BlockLibrary.gd` to load block definitions, colors, and textures dynamically from external JSON files, letting users register new blocks without modifying the source.
*   [ ] **GDExtension API Bridges:** Compile core voxel meshing and chunk generation modules into high-speed C++ via Godot's `GDExtension`, exposing clean API endpoints for heavy gameplay scripts.
*   [ ] **Custom Blueprint Importer:** Develop a tool to import standard `.vox` (MagicaVoxel) files directly into `IStructureBlueprint` instances at runtime.

---

## Phase 8: Multiplayer Networking & Client-Server Replication (Long-Term)
*Focus: Establish a high-performance multi-client synchronization layer with authoritative server physics.*

*   [ ] **UDP Voxel Replication Protocol:** Build a client-server sync pipeline using high-performance UDP packets to stream chunk modification deltas only to players within rendering range.
*   [ ] **Authoritative Physics & Prediction:** Implement server-authoritative movement physics with local client prediction and interpolation to guarantee smooth movement under high latency.
*   [ ] **Synchronized Celestial Clock:** Replicate timeline and weather states from the server's authoritative `CelestialService` and `WeatherService` across all connected client sessions.
