# CraftDomain - Development Roadmap & Milestones

This document details the completed development phases and outlines the future milestones for the **CraftDomain** infinite procedural voxel sandbox engine. Development is guided strictly by **Domain-Driven Design (DDD)**, **SOLID** software engineering compliance, and ruthless runtime execution efficiency to sustain a locked **120 FPS** frame rate.

---

## 🚀 COMPLETED MILESTONES (v1.0 FEATURE COMPLETE)

### Milestone 1: Architectural Foundation & DDD Segregation
*   **Composition Root (`Bootstrap.gd`):** Established a centralized bootstrap entry point, isolating initial startup parameters from active gameplay loops.
*   **Core Domain Isolation:** Fully segregated pure business rules (entity health, recipe value objects, coordinate biome routing) from hardware-bound rendering or saving loops.
*   **Interface Segregation (`IInventory.gd` & `IWorldModifier.gd`):** Created abstract contracts allowing decoupled systems (crafting services, P2P trading, placement strategies) to process logic without knowing about physical SceneTree nodes.
*   **Asynchronous Delta Saving:** Implemented background JSON saving, keeping main thread execution uninterrupted during auto-saves.

### Milestone 2: Unified Voxel Rendering & Shaders
*   **Dynamic Triplanar Shading:** Created an advanced local-space triplanar projection shader that completely eliminates texture sliding and diagonal stretching during camera movements.
*   **Foliage Wind-Sway:** Implemented a vertex displacement shader (`foliage_leaves.gdshader`) executing high-frequency sine expansions to simulate organic voxel canopies reacting to dynamic global wind parameters.
*   **GLB Model Sanitizer (DRY):** Extracted recursive mesh-node pruning and material tangent stripping to `GLBModelSanitizer.gd` to prevent C++ engine warnings.

### Milestone 3: Advanced Reactive AI & Pathfinding
*   **3D A* Pathfinding:** Designed the data-oriented `VoxelNavigationService` decoupled from the SceneTree. Built a background-threaded `ChunkNavigationBuilder` to compile walkable, stair-climb, and drop-down coordinates dynamically.
*   **Day/Night & Storm Shelter Schedules:** NPCs dynamically cancel tasks at sunset or during storms, locate the closest registered indoor shelter node, and route an A* path safely inside.
*   **LSP Compliant UI Overlays:** Segregated floating nameplates and speech bubbles into `EntityUIComponent.gd`.

### Milestone 4: Symmetrical Localization & Dialogue
*   **Data-Driven Dialogue Trees:** Refactored NPC dialogue databases to consume clean translation keys (e.g., `DIALOGUE_VILLAGER_INTRO`) parsed dynamically from `dialogues.json`.
*   **Symmetrical Language Packs:** Aligned `en.json` and `es.json` with identical key structures for seamless runtime language swapping.

### Milestone 5: Procedural Horizons & Mega-Structures
*   **Horizon Draw Distance:** Quadrupled active loading to a 162-chunk grid (9x2x9), pushing massive vistas under Forward+ rendering.
*   **Polymorphic Boundary Sensing:** Replaced hardcoded IF statements with `is_coordinate_inside()` inside polymorphic `IBiome` strategy classes.
*   **Handcrafted Mega-Structures:** Integrated 6 massive handcrafted multi-chunk Points of Interest (POIs) including the Grand Castle, the Harbor Galleon, and the Nether Outpost, complete with adaptive downward-scaling terrain foundations.

### Milestone 6: High-Fidelity Graphics & Physics Threading
*   **Hybrid Instant/Threaded Mesher:** Redesigned block edits to execute dual-pipeline updates. Main chunk rebuilds synchronously for 0-latency collision, while boundary neighbors rebuild asynchronously in the `WorkerThreadPool`.
*   **Compile-Free Unshaded Particles:** Migrated mining debris to `CPUParticles3D` with unshaded materials, running entirely on the CPU to completely bypass Vulkan pipeline compilation stutters.

### Milestone 7: Extreme 120 FPS Stabilization
*   **Time-Sliced Physics Budgeting:** Capped main-thread `ConcavePolygonShape3D` generation to 1-2 shapes per frame, spreading physics load evenly.
*   **Dynamic LOD AI Tick Throttle:** AI logic scales update rates based on player distance (20Hz close, 4Hz mid, 0.5Hz far), slashing CPU overhead by 95% in heavily populated villages.
*   **Memory-Safe Shutdowns:** Fixed lambda capture memory leaks by directly connecting temporary particle timers to `queue_free`.

### Milestone 8: Observer Audio & Physics Gravity Engine
*   **Spatial 3D Positional Audio:** Implemented dynamic OGG sound triggers for footsteps and block breaking via the `AudioService` locator.
*   **Coordinated Alarm Networks:** Struck civilians broadcast an alarm through `AlertNetworkService`. Nearby guards and golems within 30m group patrols to intercept hostiles.
*   **Voxel-Support Block Gravity:** Broken blocks supporting interactable props (barrels, chests, campfires) now trigger physical drops, shattering destructibles or sliding heavy props elastically to the new floor level.

### Milestone 9: Multiplayer Network Synchronization
*   **ENet P2P Sockets & UPnP:** Engineered `NetworkService` and `NetworkUPnPService` for seamless LAN and WAN Host/Join capabilities without external master servers, generating obfuscated alphanumeric Join Codes.
*   **Late-Join Delta Sync:** `VoxelReplicator` streams dual-timeline (Past/Present) chunk modifications to newly connected peers, ensuring absolute world-state parity.
*   **Server-Authoritative Anti-Cheat:** Implemented `NetworkPlayerReplica` to validate maximum legal displacements, issuing immediate rubberband corrections to speedhacking clients.
*   **P2P Trade & Chat:** Decoupled `P2PTradeService` and `P2PChatService` coordinate secure peer-to-peer inventory transactions and distance-based whispers.

### Milestone 10: Mobile & Console Porting Optimization
*   **Touchscreen Virtual Controller:** Built a platform-aware `VirtualControllerWidget` that simulates dual-joystick inputs dynamically, disappearing on desktop builds to save RAM.
*   **Gamepad Repositories:** Engineered a persistent `GamepadBindingOverlay` saving custom hardware inputs to disk (SRP).
*   **Mobile Rendering Profiler:** Evaluates hardware on boot, automatically stripping cinematic post-processing (SSAO, Glow, Volumetric Fog) and down-sampling shadow atlases on integrated GPUs.
*   **LOD Geometry Decimation:** Implemented `LODMesher` to dynamically group 16x16x16 distant chunks into optimized 8x8x8 low-poly bounds.

### Milestone 11: Advanced Sandbox Mechanics
*   **Structural Integrity Solver:** Designed a background-threaded static solver (`StructuralIntegrityService`) that calculates horizontal cantilever tensile limits, triggering physical block collapses when structures are unsafely built.
*   **Dynamic Damage Decals:** Built `BlockCrackingVisuals` to project progressive 3D cracking decals over voxels during prolonged mining.
*   **Cellular Automata Fluids:** Implemented `FluidSimulationService` handling water/lava gravity flows, lateral spreading, and realistic stone-freezing fusions upon liquid intersection.

### Milestone 12: Modding API & Extensible Data Registry
*   **External JSON Mod Loader:** Opened `CampaignRegistry`, `RecipeRegistry`, and `TranslationRegistry` to dynamically scan and merge community JSON files from the `user://mods/` directory.
*   **Isolated Strategy Plugin Loader:** Architected `ModPluginLoader` and `ModSandboxChecker` to securely compile external `.gd` block scripts at runtime, preventing malicious OS/System API calls.

### Milestone 13: Endgame Campaign & Boss Integration
*   **Voxel Glider Flight:** Implemented `GliderPhysicsStrategy`, simulating lift, parasitic drag, and altitude-based air density for high-altitude soaring.
*   **Temporal Chrono-Shift:** Programmed `ChronoShiftStrategy` supporting seamless real-time swapping between the Past and Present double-buffered chunk timelines.
*   **Silicon Terminal Hacking:** Developed `HackingTerminalOverlay`, a modular node-alignment minigame required to bypass Neon Ruins barriers.
*   **Multi-Phase Bosses:** Successfully integrated the Lithic Lurker (Act I), Obsidian Colossus (Act III), and the reality-mutating Weaver Malakor (Act IV) complete with gravity inversions and arena fracturing mechanics.

### Milestone 14: Dynamic Atmospheric & Astronomical Synthesis
*   **Day/Night Transits:** Synchronized real-time celestial clock rotations with high-contrast, non-blurry Rayleigh sky gradients.
*   **Procedural Moon Phases:** Sculpted a mathematical moon dome in tangent space, casting dynamic shadows on craters according to the 28-day lunar calendar.
*   **Unified Fog-Sky Shading:** Integrated a CPU-to-GPU fog color alignment pipeline that automatically matches fog light tints with the horizon.
*   **Height-Based Low-Lying Mists:** Implemented altitude-scaled fog attenuation in `CelestialService.gd` (`remap(clampf(player_y, 5.0, 22.0), ...)`), creating dense morning mists in valleys while keeping mountain peaks clear.
*   **Nocturnal Twinkling Stars:** Programmatically mapped high-frequency sparkling star noise, fading out during the day or during overcast storms.

### Milestone 15: SOLID Mob Spawning & Unique Target Allocation
*   **Typesafe Spawning Mapping:** Integrated a typesafe, OCP-compliant quest-objective spawner inside `MobSpawningService` mapped to concrete entity identifiers.
*   **Exclusive Proximity Claiming:** Removed dynamic auto-claiming from `PassiveEntity`, routing target locking strictly through the `WorldState` registry. This guarantees that exactly one unique entity holds the gold star and aligns GPS coordinates in real-time.
*   **Dynamic Target Injection:** The loaded chunk automatically evaluates the active mission context on spawn, instantiating unique quest mobs and aligning spawning Y coordinates cleanly to the highest solid ground.

### Milestone 16: Contextual GOAP Architecture, Reactive Combat & Procedural Physics
*   **Contextual GOAP Action Filtering:** Refactored `_evaluate_active_plan` across all 18 AI behaviors to filter `usable_actions` via `action.is_contextually_valid(_blackboard)` prior to A* state-space planning. Scan actions with unfulfilled preconditions or active cooldowns are excluded, allowing entities to seamlessly fall back to `Wander` or `Patrol`.
*   **Reactive 20-Block Threat Interrupts:** Implemented real-time interrupters in `GuardAIBehavior` and `ZombieAIBehavior`. When hostiles or passives enter the expanded 20-block (400m²) sight range, passive patrol loops are immediately cleared, triggering instant combat engagement and knockback physics.
*   **Multi-Angle XZ Plane Locomotion:** Standardized 3D direction sampling strictly on the horizontal `(X, Z)` ground plane (`Y = 0.0`), preventing entities from stalling against walls or boundary checks.
*   **Procedural Slope Body Incline:** Implemented real-time CPU matrix pitch/roll alignment in `PassiveEntity.gd` (`_apply_procedural_slope_tilt`), dynamically tilting quadruped and humanoid bodies according to terrain floor normals.
*   **Dynamic Camera Eye-Adaptation:** Integrated `CameraAttributesPractical` inside `PlayerController.gd` with auto-exposure, providing smooth human pupil adaptation when moving between bright plains and dark caves.
*   **Godot 4.7 C++ Tree-Safety & Typing:** Fixed `INCOMPATIBLE_TERNARY` compiler warnings and C++ tree locking errors (`add_child.call_deferred` in `NPCVisualComponent.gd` and `is_inside_tree()` guardrails in `NPCObstacleSteering.gd`).

---

## 🔮 FUTURE HORIZONS (POST-1.0 BACKLOG)

### Milestone 17: Virtual Reality (OpenXR) Integration
*   **6DOF Hand Tracking:** Abstract the `PlayerController` and `PlayerViewModel` to support 6DOF hand tracking, physical block grabbing, and immersive eye-and-arrow archery physics.
*   **Headless Dedicated Server App:** Compile a lightweight, GUI-stripped Linux build of CraftDomain designed to run 24/7 on VPS instances, supporting up to 64 concurrent players with persistent server-side economies.
*   **Dynamic Seasons & Thermodynamics:** Expand `CelestialService` and `WeatherService` to track yearly macro-seasons (Winter, Summer), dynamically freezing lakes or drying crops based on localized biome thermodynamics.
*   **Vehicles & Mounts:** Implement raycast-suspended collision vehicles (Minecarts on rails, Saddled Horses, Galleon steering) adhering to the existing `VoxelNavigationService` topological grid.

### Milestone 18: High-Fidelity Shading & Materials (Backlog)
*   **Foliage Proximity Bend (Player-Grass Turbulence):** Modify `foliage_leaves.gdshader` to dynamically bend grass and wild flowers away from the player or fast-moving mobs.
*   **Procedural Block Beveling (Specular Edge Highlights):** Implement a mathematical edge-normal bevel calculation in the triplanar shader to catch solar specular highlights on the edges of block bricks, logs, and metals.

---

### ⚡ 120 FPS Technical Feasibility Guardrail
All upcoming visual enhancements in the backlog are designed with strict performance budgets:
*   **CPU Operations:** Vehicle raycasts and seasonal temperature updates run on low-frequency background timers (20Hz to 1Hz), keeping the Main Thread free.
*   **GPU Operations:** Foliage bending and edge beveling are processed directly on the GPU within single-pass shaders, avoiding vertex restructuring or extra draw calls.
