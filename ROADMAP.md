# CraftDomain - Development Roadmap & Milestones

This document details the completed development phases and outlines the future milestones for the **CraftDomain** infinite voxel sandbox engine. Development is guided strictly by Domain-Driven Design (DDD), SOLID software engineering compliance, and runtime execution efficiency.

---

## 🚀 Completed Milestones

### Milestone 1: Architectural Foundation & DDD Segregation
*   **Composition Root (`Bootstrap.gd`):** Established a centralized bootstrap entry point, isolating initial startup parameters from active gameplay loops.
*   **Core Domain Isolation:** Fully segregated pure business rules (such as entity health, recipe value objects, and coordinate biome routing) from hardware-bound rendering or saving loops.
*   **Interface Segregation (`IInventory.gd`):** Created abstract inventory contracts, allowing decoupled systems (crafting services, trading droids) to process items without knowledge of physical character nodes.
*   **Asynchronous Saving:** Implemented background delta JSON saving in the `user://` directory, storing precise coordinates, 24-slot inventory statuses, and active quest chains smoothly.

### Milestone 2: Unified Voxel Rendering & Shaders Overhaul
*   **Multi-Mesh Partitioning:** Segregated rendering segments by `BlockType` to apply tailored materials (translucent, glossy water, reflective glass, and emissive glowing lava).
*   **Dynamic Triplanar Shading:** Created an advanced local-space triplanar projection shader (`triplanar_blocks.gdshader`) that completely eliminates texture sliding, warping, or diagonal stretching during camera movements.
*   **Foliage Wind-Sway:** Implemented a wind-swat displacement shader (`foliage_leaves.gdshader`) executing high-frequency sine expansions along normals to simulate organic voxel canopies.
*   **Voxel Grain Texturing:** Programmed a shared, statically cached high-frequency cellular noise texture applied with `TEXTURE_FILTER_NEAREST` to paint detailed, blocky textures over all animal and NPC meshes with zero performance overhead.

### Milestone 3: Advanced Reactive AI & Variety
*   **Deterministic Variant Seeding:** Designed coordinate-based randomization loops inside `PassiveEntity.gd` to proceduralize outfits, skin tones, hair colors, and height scales so no two neighbors look identical.
*   **Conversational Gaze-Locks:** Updated the dialogue coordinators to pass the active speaker's node reference. Interacting with NPCs freezes their physical velocities, pauses walk cycles, and rotates their visual meshes smoothly to maintain eye contact.
*   **Defensive Guard Aggro:** Programmed active protector behaviors in `GuardEntity.gd`. Guards draw their sheathed back swords and sprint to attack any zombie within 10 meters.
*   **Automated Agricultural Farmers:** Enhanced farmers to scan for mature crops, wander to them, draw their harvesting hoes, and swing them up and down to harvest and replant seeds with green particle feedback.

### Milestone 4: Symmetrical Localization & Dialogue
*   **Dialogue Translation Keys:** Refactored all NPC dialogue databases and fallback prompts to consume clean translation keys (e.g. `DIALOGUE_VILLAGER_INTRO`) rather than hardcoded English.
*   **Dynamic Greeting Pools:** Integrated coordinate-seeded variety indices inside NPC conversation routers to serve unique situational lines based on time, biomes, or random rolls.
*   **Symmetrical Language Packs:** Re-aligned both `en.json` and `es.json` to possess the exact same key structures, spacings, and sorting order to prevent parser drift during localization lookups.

### Milestone 5: Procedural Horizons & Biomes Expansion
*   **Horizon Draw Distance:** Quadrupled the active loading radius inside `ChunkLoaderService.gd` to load a 3D 162-chunk grid (9x2x9 chunks), rendering beautiful vistas under Forward+.
*   **Themed Spawning Outposts:** Updated `MobSpawningService.gd` to inspect the loaded outpost's active Biome ID and dynamically deploy specialized populations (Druids in Redwoods, Miners with active headlamps in mountains, Androids in Cyber ruins).
*   **New Landscape Blueprints:** Programmed, registered, and scattered three new blueprints: slender white-barked **Birch Trees** (ID 13), flowering **Rose Bushes** (ID 12), and dry desert **Dead Shrubs** (ID 14).
*   **Aquatic Sea Turtles:** Introduced paddling, swimming Sea Turtles (`ID 201`) spawning exclusively inside the water bodies of ocean biomes.

---

## 🔮 Future Milestones (Backlog)

### Milestone 6: Multiplayer Network Synchronization (High Priority)
*   **Decoupled Network Controllers:** Split local player inputs into independent client-side predict/interpolate networks, supporting server-authoritative command replication.
*   **High-Frequency Delta Sync:** Serialize and replicate only block modification deltas and active entity positions across the network via ENet or WebSockets to minimize bandwidth consumption.
*   **Decoupled Chat & Trade Managers:** Adapt the abstract `IInventory` and dialogue systems to support secure, transactional player-to-player trading and chat channels.

### Milestone 7: 3D Cave Carving & Fluid Cellular Automata
*   **True 3D Cave Generation:** Upgrade the 2D height noise algorithms with 3D Simplex Noise equations to procedurally carve underground tunnels, shafts, and natural cavern hollows.
*   **Fluid Cellular Automata:** Implement a high-performance, background-threaded cellular automata pipeline to compute natural, flowing fluid dynamics for water and lava.
*   **Optimized Cubic Chunking:** Transition chunk storage from monolithic columns to vertical cubic segments (16x16x16 blocks) to support infinite building heights up to the stratosphere.

### Milestone 8: Mobile & Console Porting Optimization
*   **Controller Mapping Overlay:** Create a modular controller mapping overlay, utilizing Godot's Input Action mappings to support seamless Steam Deck and gamepad navigations.
*   **Vulkan Mobile Rendering:** Compile a specialized rendering pipeline tailored for mobile GPUs, aggressively compressing MultiMesh draw calls.
*   **LOD Chunking (Level of Detail):** Develop a Level-of-Detail mesher that reduces the vertex count of distant chunks to maintain solid framerates on lower-spec mobile hardware.
