# CraftDomain - Development Roadmap & Milestones

This document details the completed development phases and outlines the future milestones for the **CraftDomain** infinite voxel sandbox engine. Development is guided strictly by **Domain-Driven Design (DDD)**, **SOLID** software engineering compliance, and ruthless runtime execution efficiency.

---

## 🚀 Completed Milestones

### Milestone 1: Architectural Foundation & DDD Segregation
*   **Composition Root (`Bootstrap.gd`):** Established a centralized bootstrap entry point, isolating initial startup parameters from active gameplay loops.
*   **Core Domain Isolation:** Fully segregated pure business rules (such as entity health, recipe value objects, and coordinate biome routing) from hardware-bound rendering or saving loops.
*   **Interface Segregation (`IInventory.gd`):** Created abstract inventory contracts, allowing decoupled systems (crafting services, trading droids) to process items without knowledge of physical character nodes.
*   **Asynchronous Saving:** Implemented background delta JSON saving in the `user://` directory, storing precise coordinates, 24-slot inventory statuses, and active quest chains smoothly.

### Milestone 2: Unified Voxel Rendering & Shaders Overhaul
*   **Multi-Mesh Partitioning:** Segregated rendering segments by `BlockType` to apply tailored materials (translucent, glossy water, reflective glass, and emissive glowing lava).
*   **Dynamic Triplanar Shading:** Created an advanced local-space triplanar projection shader that completely eliminates texture sliding, warping, or diagonal stretching during camera movements.
*   **Foliage Wind-Sway:** Implemented a wind-sway displacement shader executing high-frequency sine expansions along normals to simulate organic voxel canopies.
*   **Voxel Grain Texturing:** Programmed a shared, statically cached high-frequency cellular noise texture applied with `TEXTURE_FILTER_NEAREST` to paint detailed, blocky textures over all animal and NPC meshes with zero performance overhead.

### Milestone 3: Advanced Reactive AI & Variety
*   **Deterministic Variant Seeding:** Designed coordinate-based randomization loops inside `PassiveEntity.gd` to proceduralize outfits, skin tones, hair colors, and height scales so no two neighbors look identical.
*   **Conversational Gaze-Locks:** Updated the dialogue coordinators to pass the active speaker's node reference. Interacting with NPCs freezes their physical velocities, pauses walk cycles, and rotates their visual meshes smoothly to maintain eye contact.
*   **Defensive Guard Aggro:** Programmed active protector behaviors. Guards draw their sheathed back swords and sprint to attack any zombie within 10 meters.
*   **Automated Agricultural Farmers:** Enhanced farmers to scan for mature crops, wander to them, draw their harvesting hoes, and swing them up and down to harvest and replant seeds with green particle feedback.

### Milestone 4: Symmetrical Localization & Dialogue
*   **Dialogue Translation Keys:** Refactored all NPC dialogue databases and fallback prompts to consume clean translation keys (e.g. `DIALOGUE_VILLAGER_INTRO`) rather than hardcoded English.
*   **Dynamic Greeting Pools:** Integrated coordinate-seeded variety indices inside NPC conversation routers to serve unique situational lines based on time, biomes, or random rolls.
*   **Symmetrical Language Packs:** Re-aligned both `en.json` and `es.json` to possess the exact same key structures, spacings, and sorting order to prevent parser drift during localization lookups.

### Milestone 5: Procedural Horizons & Biomes Expansion
*   **Horizon Draw Distance:** Quadrupled the active loading radius inside `ChunkLoaderService.gd` to load a 3D 162-chunk grid (9x2x9 chunks), rendering beautiful vistas under Forward+.
*   **Themed Spawning Outposts:** Updated `MobSpawningService.gd` to inspect the loaded outpost's active Biome ID and dynamically deploy specialized populations (Druids in Redwoods, Miners with active headlamps in mountains, Androids in Cyber ruins).
*   **Global Mega-Structures:** Engineered massive, multi-chunk architectural POIs (Grand Castle, Nether Outpost, Steve's Cabin) that overwrite procedural terrain at fixed coordinates.

### Milestone 6: High-Fidelity Graphics & Physics Threading
*   **Thread-Safe Physics Shape Compilation:** Prevented the `PhysicsServer3D` background lock by extracting flat collision vertex arrays on worker threads and instantiating the single concave body on the main thread.
*   **Group AI Targeting ($O(1)$ complexity):** Replaced slow, high-frequency $O(N)$ child-seeking loops with fast, native Godot group lookups (`"hostiles"` and `"passives"`).
*   **Procedural Bevel Normal Mapping (Selective):** Programmatically baked a perfect 64x64 bevel normal map in RAM at startup to simulate beautiful rounded corners on building blocks under direct sunlight.
*   **Global Wind Shader System:** Integrated dynamic wind vectors and wind strength as global shader uniforms (`"wind_vector"`), making water waves and leaf sways physically react to storms in complete, zero-cost synchronicity.

### Milestone 7: Extreme 120 FPS Stabilization & Memory Pooling
*   **ChunkNode Object Pooling:** Implemented dynamic recycling of `ChunkNode` instances inside `ChunkManagerService.gd` to completely eliminate Garbage Collection stuttering during fast travel.
*   **Time-Sliced Physics Budgeting:** Capped main-thread `ConcavePolygonShape3D` generation to 1-2 shapes per frame, spreading the physics load perfectly over time.
*   **UI / AI Scan Throttling:** Reduced $O(1)$ group tactical scans and HUD metric updates (like GPS coordinate tracking) from 120Hz to 4Hz/20Hz, slashing CPU load by 95% in heavily populated areas without sacrificing responsiveness.
*   **Opaque Far-LOD Culling:** Disabled alpha-blending (`TRANSPARENCY_DISABLED`) on distant translucent chunks (water, glass, ice, clouds) to save massive GPU pixel fillrate on the horizon.

### Milestone 8: Commercial UI/UX Overhaul
*   **Tactile Glassmorphism:** Upgraded all menus (Main Menu, Settings, Pause, Inventory) with responsive `PanelContainers`, dynamic pivots, and physical 3D button depression Tweens.
*   **Sub-pixel Hermetic Sealing:** Mathematically scaled liquid and custom solid (Slab) vertices by `1.002` to perfectly overlap chunk boundaries, permanently fixing Z-fighting and light leaks.
*   **Precision Mathematical Alignment:** Re-anchored hotbar docks, status bars (Hearts/Food), and floating speech bubbles to guarantee pixel-perfect symmetry and zero layout shifting.

### Milestone 9: Observer Audio Engine
*   **Service Locator Pattern:** Implemented `AudioService.instance` for zero-coupling static access, allowing any pure Domain event to trigger sound effects instantly.
*   **Spatial 3D Positional Audio:** Added dynamic OGG sound triggers for block breaking, placing, sword swings, chest openings, and NPC interactions that auto-free upon completion.
*   **Seamless Soundtrack Crossfading:** Implemented double-buffered audio streams to smoothly transition between Day, Combat, Cyber, and Polar EDM tracks based on biome and time of day.
*   **Dynamic Footstep Accumulator:** Tracked player velocity lengths to trigger terrain-specific footstep audio (Grass, Stone, Wood, Snow) accurately based on the exact block beneath the player's feet.

---

## 🔮 Future Milestones (Backlog)

### Milestone 10: Multiplayer Network Synchronization (High Priority)
*   **Decoupled Network Controllers:** Split local player inputs into independent client-side predict/interpolate networks, supporting server-authoritative command replication.
*   **High-Frequency Delta Sync:** Serialize and replicate only block modification deltas and active entity positions across the network via ENet or WebSockets to minimize bandwidth consumption.
*   **Decoupled Chat & Trade Managers:** Adapt the abstract `IInventory` and dialogue systems to support secure, transactional player-to-player trading and chat channels.

### Milestone 11: 3D Cave Carving & Fluid Cellular Automata
*   **True 3D Cave Generation:** Upgrade the 2D height noise algorithms with 3D Simplex Noise equations to procedurally carve underground tunnels, shafts, and natural cavern hollows.
*   **Fluid Cellular Automata:** Implement a high-performance, background-threaded cellular automata pipeline to compute natural, flowing fluid dynamics for water and lava.
*   **Optimized Cubic Chunking:** Transition chunk storage from monolithic columns to vertical cubic segments (16x16x16 blocks) to support infinite building heights up to the stratosphere.

### Milestone 12: Mobile & Console Porting Optimization
*   **Controller Mapping Overlay:** Create a modular controller mapping overlay, utilizing Godot's Input Action mappings to support seamless Steam Deck and gamepad navigations.
*   **Vulkan Mobile Rendering:** Compile a specialized rendering pipeline tailored for mobile GPUs, aggressively compressing MultiMesh draw calls.
*   **LOD Geometry Decimation:** Develop a Level-of-Detail mesher that reduces the vertex count of distant chunks to maintain solid framerates on lower-spec mobile hardware.

### Milestone 13: Advanced Sandbox Mechanics
*   **Structural Integrity Solver:** Design a background-threaded static structural solver that calculates physical tension limits of building blocks and triggers physical collapses when blocks are unsafely cantilevered.
*   **Dynamic Block Damage Overlay:** Program a decoupled progress cracking texture system that applies overlay decals to voxel faces during prolonged mining interactions.

### Milestone 14: Modding API & Extensible Data Registry
*   **External JSON Mod Loader:** Open up the `CampaignRegistry`, `RecipeRegistry`, and `BlockLibrary` to scan and merge external JSON files from an isolated `user://mods/` directory on startup.
*   **Isolated Strategy Plugin Loader:** Architect a sandboxed script-loader utilizing Godot's built-in `Plugin` or isolated `GDScript` loaders to allow modders to register custom block strategies and biome routing entirely without modifying the engine's source code.

----
