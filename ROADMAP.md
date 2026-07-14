# CraftDomain - Development Roadmap & Milestones

This document details the completed development phases and outlines the future milestones for the **CraftDomain** infinite voxel sandbox engine. Development is guided strictly by **Domain-Driven Design (DDD)**, **SOLID** software engineering compliance, and ruthless runtime execution efficiency to sustain a locked **120 FPS** frame rate.

---

## 🚀 Completed Milestones

### Milestone 1: Architectural Foundation & DDD Segregation
*   **Composition Root (`Bootstrap.gd`):** Established a centralized bootstrap entry point, isolating initial startup parameters from active gameplay loops.
*   **Core Domain Isolation:** Fully segregated pure business rules (such as entity health, recipe value objects, and coordinate biome routing) from hardware-bound rendering or saving loops.
*   **Interface Segregation (`IInventory.gd` & `IWorldModifier.gd`):** Created abstract inventory and modification contracts, allowing decoupled systems (crafting services, trading droids, placement strategies) to process items and blocks without knowledge of physical character nodes.
*   **Asynchronous Saving:** Implemented background delta JSON saving in the `user://` directory, storing precise coordinates, 24-slot inventory statuses, and active quest chains smoothly.
*   **Persistence Decoupling (SRP):** Split the repository layer into **`VoxelSaveSerializer.gd`** (which handles coordinate packing and state translations exclusively) and **`DiskWorldRepository.gd`** (which handles direct file streams and OS directories exclusively).
*   **Pathing Mathematics Isolation:** Slashed file-system pathing arithmetic inside `DiskWorldRepository.gd`, isolating all persistent directories, chunk file suffixes, and JSON extensions inside the static Value Object `SavePathConfiguration.gd`.
*   **Strict Deserialization Unpacking:** Decomposed `VoxelSaveSerializer.gd`'s unpacked methods into highly specialized, statically typed, and error-safe private helpers (such as `_unpack_player_position` and `_unpack_player_rotation`), completely eliminating silent JSON parsing crashes or generic `Variant` type mismatches.

### Milestone 2: Unified Voxel Rendering & Shaders Overhaul
*   **Multi-Mesh Partitioning:** Segregated rendering segments by `BlockType` to apply tailored materials (translucent, glossy water, reflective glass, and emissive glowing lava).
*   **Dynamic Triplanar Shading:** Created an advanced local-space triplanar projection shader that completely eliminates texture sliding, warping, or diagonal stretching during camera movements.
*   **Foliage Wind-Sway:** Implemented an external wind-sway displacement shader (`foliage_leaves.gdshader`) executing high-frequency sine expansions along normals to simulate organic voxel canopies.
*   **Voxel Grain Texturing:** Programmed a shared, statically cached high-frequency noise texture applied with `TEXTURE_FILTER_NEAREST` to paint detailed, blocky textures over all animal and NPC meshes with zero performance overhead.
*   **GLB Model Sanitizer (DRY):** Extracted recursive mesh-node pruning and material overrides to `GLBModelSanitizer.gd`, stripping over 300 lines of duplicate, copy-pasted rendering cleanup code from 20+ active creature and prop scripts.

### Milestone 3: Advanced Reactive AI, Pathfinding & Variety
*   **3D A* Pathfinding:** Designed the data-oriented **`VoxelNavigationService`** leveraging Godot's C++ `AStar3D` solver, completely decoupled from the SceneTree. Built a spatial `ChunkNavigationBuilder` to compile walkable, stair-climb, and drop-down coordinates dynamically as chunks render on the main thread.
*   **Day/Night & Storm Shelter Schedules:** Refactored `NPCAIComponent.gd` to execute real-time schedules. At sunset or during storms, civilian NPCs dynamically cancel tasks, locate the closest cached indoor shelter node, and route an A* path straight to it.
*   **3D Floating Nameplates & LSP Compliance:** Added native `Label3D` billboarding nameplates. Resolved scene-tree name-collisions polimorphically by evaluating the class type (`self is ClassType`) rather than reading node names. Excluded wild animals from carrying civilian conversation nodes via `_has_ui_decorations()`.
*   **Conversational Gaze-Locks:** Updated the dialogue coordinators to pass the active speaker's node reference. Interacting with NPCs freezes their physical velocities, pauses walk cycles, and rotates their visual meshes smoothly to maintain eye contact.
*   **Automated Agricultural Farmers:** Enhanced farmers to scan for mature crops, wander to them, draw their harvesting hoes, and swing them up and down to harvest and replant seeds with green particle feedback.

### Milestone 4: Symmetrical Localization & Dialogue
*   **Dialogue Translation Keys:** Refactored NPC dialogue databases and fallback prompts to consume clean translation keys (e.g. `DIALOGUE_VILLAGER_INTRO`) rather than hardcoded strings.
*   **Dynamic Greeting Pools:** Integrated coordinate-seeded variety indices inside NPC conversation routers to serve unique situational lines based on time, biomes, or random rolls.
*   **Symmetrical Language Packs:** Re-aligned both `en.json` and `es.json` to possess the exact same key structures, spacings, and sorting order to prevent parser drift during localization lookups. Corrected all incomplete translations.

### Milestone 5: Procedural Horizons, Structure Blueprints & Mega-Structures
*   **Horizon Draw Distance:** Quadrupled the active loading radius inside `ChunkLoaderService.gd` to load a 3D 162-chunk grid (9x2x9 chunks), rendering beautiful vistas under Forward+.
*   **Polymorphic Boundary Sensing:** Removed the hardcoded coordinate angle/sector split calculations inside `BiomeService.gd`. Concrete `IBiome` strategy classes now encapsulate their own territorial boundaries polimorphically using `is_coordinate_inside()`.
*   **Themed Spawning Outposts:** Updated `MobSpawningService.gd` to inspect the loaded outpost's active Biome ID and dynamically deploy specialized populations (Druids in Redwoods, Miners with active headlamps in mountains, Androids in Cyber ruins).
*   **100% Compiled Structure Registry (OCP/YAGNI Overhaul):** Refactored all data-driven layout JSON templates (`mine_pillar`, `harbor_pier`, `market_cabin`, `ice_temple`, `neon_pyramid`, and `warp_pipe`) into dynamically adapting compiled GDScript blueprints (`IStructureBlueprint.gd`). Completely deleted `TemplateStructureBlueprint.gd` and raw structures assets to achieve pure, zero-I/O RAM-based generation.
*   **Adaptive Placements:** Enhanced the structural blueprints with vertical column scanning to procedurally build solid foundations down to sloped terrain or seabed depths, preventing floating blocks on hillsides or sea cliffs.
*   **Playable 3D Handcrafted Mega-Structures:** Completely remodeled fixed multi-chunk Points of Interest (POIs) with playable 3D interiors, multi-floor compartments, and wide, comfortable staircase climbs:
	*   *The Grand Castle `[200, 200]`:* A colossal two-story fortress containing a cathedral-like double-height Throne Hall, majestic 3-block wide double-rising stairs, upper suites (King's bedroom with cloud bed, Queen's, and War Council), a high-security Royal Treasury with pedestals, and active steps leading to crenellated rooftop battlements. Recalibrated fast travel to land safely on the entrance bridge.
	*   *The Seaport & Galleon `[-150, 0]`:* Expanded docks with stacked cargo and a 2-story tavern ("The Salty Sailor Inn" with bar counters and stairs), and a moored three-deck Galleon Ship containing crew bunks, cargo hold, and quarterdeck Captain's Cabin with glass popa windows.
	*   *The Nether Outpost `[-300, -300]`:* A tattered lava citadel flanked by concentric magma canals and bridges, housing a massive double-height Portal Sanctuary and an elevated treasury room.
	*   *Steve's Cabin `[300, -300]`:* Redesigned into a detailed village spanned by a giant parabolic mossy stone archway, central plaza fountain, tilled wheat plots, a 2-story cozy log lodge, and a towering windmill with fully accessible interior floors.
	*   *Desert Oasis Pyramid `[-150, 250]`:* An 8-tier stepped sandstone pyramid built over water, housing an ancient Sarcophagus altar, wide side stairs, and an enclosed Pharaoh's Vault containing the Loot Chest sitting on a brick pedestal.

### Milestone 6: High-Fidelity Graphics & Physics Threading
*   **Hybrid Instant/Threaded Mesher:** Redesigned block edits to execute a dual-pipeline update. The modified chunk is rebuilt synchronously on the main thread for 0-latency collision, while boundary neighboring chunks are offloaded asynchronously to background hilos, completely eliminating mining stutters.
*   **Compile-Free Unshaded Particles:** Migrated mining debris generators to use **`CPUParticles3D`** with unshaded materials. This runs entirely on the CPU and completely avoids dynamic Vulkan pipeline compilations on the GPU.
*   **Group AI Targeting ($O(1)$ complexity):** Replaced slow, high-frequency $O(N)$ child-seeking loops with fast, native Godot group lookups (`"hostiles"` and `"passives"`).
*   **Procedural Bevel Normal Mapping (Selective):** Programmatically baked a perfect 64x64 bevel normal map in RAM at startup to simulate rounded corners on building blocks under direct sunlight.
*   **Global Wind Shader System:** Integrated dynamic wind vectors and wind strength as global shader uniforms (`"wind_vector"`), making water waves and leaf sways physically react to storms in complete, zero-cost synchronicity.

### Milestone 7: Extreme 120 FPS Stabilization & Memory Pooling
*   **ChunkNode Object Pooling:** Implemented dynamic recycling of `ChunkNode` instances inside `ChunkManagerService.gd` to completely eliminate Garbage Collection stuttering during fast travel.
*   **Time-Sliced Physics Budgeting:** Capped main-thread `ConcavePolygonShape3D` generation to 1-2 shapes per frame, spreading the physics load perfectly over time.
*   **Dynamic LOD AI Tick Throttle:** AI logical update rates scale dynamically based on distance to the player (20Hz close, 4Hz mid, 0.5Hz far), slashing CPU processing overhead by over 95% in heavily populated areas.
*   **Opaque Far-LOD Culling:** Disabled alpha-blending (`TRANSPARENCY_DISABLED`) on distant translucent chunks (water, glass, ice, clouds) to save massive GPU pixel fillrate on the horizon.
*   **Memory-Safe Shutdown Timers:** Configured all temporary particle timers to connect their timeout signals directly to `particles.queue_free`, permanently preventing `Lambda capture at index 0 was freed` memory leaks upon world exit.

### Milestone 8: Commercial UI/UX Overhaul
*   **Skins Scene Migration:** Migrated 100% of HUD panels, overlays, and widgets from procedural code drawing to declarative `.tscn` and `.tres` theme assets (reducing UI scripts like `MainMenu.gd`, `SettingsMenu.gd`, `PauseMenuWidget.gd`, `CraftingOverlay.gd`, `InventoryOverlay.gd` to under 50-100 lines, adhering strictly to SRP).
*   **Decoupled Slot Widgets (SRP):** Extracted the `InventorySlotWidget.gd` from the main panel to isolate cell rendering and drag-and-drop operations from layout containers.
*   **Duplicate Color Map Deletion:** Completely deleted the hardcoded, duplicate `BLOCK_COLORS` map from `HotbarDockWidget.gd` and `InventoryOverlay.gd`. The UI now queries the Domain `BlockLibrary` directly for accurate fallback colors.
*   **Corrected Checklist Verification:** Re-engineered the crafting checklist. It now queries the player's total cumulative stock of the required item globally using `get_item_total_quantity()` instead of checking slot indexes.
*   **Sub-pixel Hermetic Sealing:** Mathematically scaled liquid and custom solid (Slab) vertices by `1.002` to perfectly overlap chunk borders, permanently fixing Z-fighting and light leaks.

### Milestone 9: Observer Audio & Physics Gravity Engine
*   **Service Locator Pattern:** Implemented `AudioService.instance` for zero-coupling static access, allowing any pure Domain event to trigger sound effects instantly.
*   **Spatial 3D Positional Audio:** Added dynamic OGG sound triggers for block breaking, placing, sword swings, chest openings, and NPC interactions that auto-free upon completion.
*   **Coordinated Alarm Networks:** Struck civilians find the closest hostile and broadcast an alarm through `AlertNetworkService.instance`. Nearby guards and golems within 30m immediately run to intercept.
*   **Village Reputation & Karma:** Attacking civilians deducts reputation points. Falling below the outlaw threshold causes protectors to turn hostile, while high reputation grants up to a 30% price discount at Merchant stalls.
*   **Voxel-Support Block Gravity:** Added support checking. Broken blocks supporting a Barrel, Chest, or Campfire cause the prop to shatter and drop loot, while heavy Wishing Wells and Streetlights slide down smoothly with elastic bouncing Tweens.
*   **Harvesting Bugs Resolved:** Reclassified leaves as solid so they can be mined. Mining Ice (in glaciers) and Mud (in swamps) now correctly yields clean Water blocks.

### Milestone 11: 3D Cave Carving & Fluid Cellular Automata (Overhaul Completed)
*   **True 3D Cave Generation:** Programmed 3D Simplex fractal ridged noise (`_cave_noise` inside `WorldGenerator.gd`) to procedurally carve interconnected subterranean cave networks and spaghetti tunnel shafts.
*   **Fluid Cellular Automata:** Implemented high-performance, queue-based fluid dynamics in `FluidSimulationService.gd` to simulate water and lava gravity flows, lateral spreading, and realistic stone-freezing fusions when opposing fluid blocks intersect.
*   **Unified CPU Normal Baking:** Restored `generate_normals()` inside `ChunkMesher.gd` before committing custom fluid meshes, correcting PBR speculation and enabling vertex-wave displacement (`NORMAL.y > 0.5`) inside the external water shader (`liquid_water.gdshader`).

### Milestone 15: Foundational Narrative Campaign & Lore Synchronization
*   **Lore Bible Compilation:** Established the complete cosmology, space-time mechanics, character profiles, and faction ideologies inside [docs/lore/00_MASTER_BIBLE.md](docs/lore/00_MASTER_BIBLE.md).
*   **Act I Script Completed:** Designed Chapters I through IV inside [docs/lore/01_ACT_I_DAWN.md](docs/lore/01_ACT_I_DAWN.md), mapping the shipwreck, Maelor's dialogue, Valerius's alchemical chicken story, and Golem Aethelgard's activation.
*   **Act II Script Completed:** Compiled the search for the relics inside [docs/lore/02_ACT_II_RELICS.md](docs/lore/02_ACT_II_RELICS.md), including canyon glider mechanics, redwood Sages, and Neon Ruins hacking consoles.
*   **Act III Script Completed:** Fleshed out the swamp alchemy, Nether fortress siege, tattered throne keep defense, and Void rift dimensions inside [docs/lore/03_ACT_III_SHADOW.md](docs/lore/03_ACT_III_SHADOW.md).
*   **Act IV Script Completed:** Outlined the glitched stratosphere climb, Cloud Kingdom, Malakor's multi-phase boss fight, and the player's heroic farewell inside [docs/lore/04_ACT_IV_ASCENSION.md](docs/lore/04_ACT_IV_ASCENSION.md).
*   **Side Quests Guild System:** Formulated non-linear side stories for Barnaby, Druid Fawns, and the Great White Shark hunt inside [docs/lore/05_SIDE_QUESTS.md](docs/lore/05_SIDE_QUESTS.md).
*   **Bestiary and Habitat Rules:** Compiled technical AI routines, cylinder physical bounds, and strengths/weaknesses inside [docs/lore/06_BESTIARY_COMPENDIUM.md](docs/lore/06_BESTIARY_COMPENDIUM.md).
*   **Voxel Metaphysics and Crafting:** Documented the block composition states and alchemical transmutation recipes inside [docs/lore/07_ALCHEMY_CRAFTING.md](docs/lore/07_ALCHEMY_CRAFTING.md).
*   **Branching Dialogues and Economy:** Mapped situational civilian greetings, guard warnings, and reputation merchant discounts inside [docs/lore/08_DIALOGUE_GRIMOIRE.md](docs/lore/08_DIALOGUE_GRIMOIRE.md).

### Milestone 16: Act I Boss Integration (Completed)
*   **The Lithic Lurker Boss Battle:** Successfully coded and integrated the first multi-phase boss encounter of the campaign. Implemented `LithicLurkerAIBehavior.gd` (4-phase state machine with core-exposed stunned window vulnerabilities), `LithicLurkerModelBuilder.gd` (procedural dark basalt sculptor with glowing emissive core details), and `LithicLurkerEntity.gd` (controlling physical combat, AoE ground-pound impacts, and volcanic drops).
*   **Basalt Crater Arena:** Created `LithicLurkerLairMegaStructure.gd`, a handcrafted volcanic crater structure located at fixed coordinates `[-100, 100]` under the Craggy Peaks, complete with scattered lava pools, to spawn and anchor the boss in the world.

### Milestone 17: 100% Decoupled AI Strategy Integration (Backlog Completed)
*   **AI Strategy Overhaul:** Decoupled 100% of the remaining unique entity and wildlife behaviors from Infrastructure physical controllers into pure, testable Domain strategy classes (`src/Domain/Life/...`).
*   **Physics Controllers Purification:** Refactored all entity physics scripts (`PassiveEntity.gd` and `NPCAIComponent.gd`) to act as pure visual and translation presenters, removing all direct, inline logical variables, and injecting decoupled sub-components (`EntityUIComponent.gd` and `NPCObstacleSteering.gd`).
*   **Humanoid DRY Centralization:** Purged the duplicated 12-line coordinate-seeded `_detect_current_biome()` method from all 6 specialized humanoids, centralizing geography queries polimorphically inside `BiomeService.get_biome_id_at_position()`.

---

## 🔮 Future Milestones (Backlog)

### Milestone 10: Multiplayer Network Synchronization (High Priority)
*   **Decoupled Network Controllers:** Split local player inputs into independent client-side predict/interpolate networks, supporting server-authoritative command replication.
*   **High-Frequency Delta Sync:** Serialize and replicate only block modification deltas and active entity positions across the network via ENet or WebSockets to minimize bandwidth consumption.
*   **Decoupled Chat & Trade Managers:** Adapt the abstract `IInventory` and dialogue systems to support secure, transactional player-to-player trading and chat channels.

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

### 🏹 Milestone 16: Campaign Integration & Advanced Narrative Mechanics (Remaining Backlog)
*   **Voxel Glider Flight Controller:** Develop a high-altitude aerodynamic controller inside `PlayerController.gd` to translate vertical kinetic energy into smooth horizontal soaring.
*   **Temporal Chrono-Shift Engine:** Implement a chunk-wide historical snapshot loader allowing the player to swap voxel terrains to past timelines during Act II puzzle resolutions.
*   **Silicon Terminal Hacking Minigame:** Program a modular, graph-based overlapping node UI enabling cyber-hacking mechanics within the Neon Ruins.
*   **Multi-Phase Boss Battles:** Design state machine AI patterns for the Obsidian Colossus (Act III), and the reality-mutating Weaver Malakor (Act IV).
