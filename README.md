# CraftDomain

![MainMenu Background](src/Infrastructure/UI/Assets/menu_background.png)

A high-performance, commercial-grade infinite procedural voxel sandbox game engine built in **Godot 4.6.3** adhering to strict **Domain-Driven Design (DDD)** principles, conventional Conventional Commits tracking, and rigorous **SOLID** software engineering compliance. Architected to demonstrate a highly decoupled, modular, and extensible system capable of maintaining a locked, rock-solid **120 FPS** with smooth frame pacing in massive, thread-populated 3D environments.

---

## 🏗️ Architectural Philosophy: Domain-Driven Design (DDD)

CraftDomain is architected using **Domain-Driven Design (DDD)** patterns. By segregating the codebase into distinct layers, we isolate pure business rules (the "Domain") from framework-specific engine details (the "Infrastructure"), such as Vulkan rendering, physics bodies collisions, disk JSON I/O, and audio buses.

### Layer Segmentation & Dependency Flow

```mermaid
graph TD
	subgraph Core_Bootstrap [Core / Bootstrap Layer]
		Bootstrap[Bootstrap.gd - Composition Root]
		Preloader[EntityPreloaderRegistry.gd - Static Preloader]
	end

	subgraph Infrastructure_Layer [Infrastructure Layer]
		WorldController[WorldController.gd - Coordinator]
		ChunkManager[ChunkManagerService.gd - Object Pooling]
		ChunkNode[ChunkNode.gd - MultiMesh]
		ChunkMesher[ChunkMesher.gd - Custom Mesh Baker]
		PlayerController[PlayerController.gd - Physics Presenter]
		VoxelInteraction[VoxelInteractionComponent.gd - Raycaster]
		BlockCracking[BlockCrackingVisuals.gd - Crack Renderer]
		NPCAI[NPCAIComponent.gd - Sensory Brain]
		NPCObstacle[NPCObstacleSteering.gd - 3D Steerer]
		EntityUI[EntityUIComponent.gd - Floating UI Presenter]
		DiskWorldRepo[DiskWorldRepository.gd - JSON I/O]
		SavePath[SavePathConfiguration.gd - Path Value Object]
		Sanitizer[GLBModelSanitizer.gd - Model Pruner]
		DialogueManager[DialogueManager.gd - Input Blocker]
		AudioService[AudioService.gd - Crossfading Soundscape]
		CelestialService[CelestialService.gd - Astronomical Orbits]
	end

	subgraph Domain_Layer [Domain Layer]
		WorldState[WorldState.gd - Aggregate Root]
		Chunk[Chunk.gd - Voxel Grid]
		VoxelEntity[VoxelEntity.gd - Health & Combat]
		IBiome[IBiome.gd - Strategy Interface]
		IInventory[IInventory.gd - Interface Segregation]
		QuestService[QuestService.gd - Domain Quest State]
		DialogueService[DialogueService.gd - Dialogue Router]
		CraftingService[CraftingService.gd - Transaction Logic]
		IWorldModifier[IWorldModifier.gd - Adapter]
		VoxelNavigationService[VoxelNavigationService.gd - 3D AStar Graph]
		AlertNetworkService[AlertNetworkService.gd - Proximity Alarms]
		VillageReputationService[VillageReputationService.gd - Karma Engine]
		IAIBehavior[IAIBehavior.gd - AI Strategy Interface]
		IStructureBlueprint[IStructureBlueprint.gd - Map Strategy Interface]
	end

	Bootstrap -->|Injects Repositories & Controllers| WorldController
	Bootstrap -->|Queries preloaded assets| Preloader
	WorldController -->|Queries & Updates| WorldState
	WorldState -->|Contains| Chunk
	ChunkNode -->|Renders| Chunk
	ChunkNode -->|Calls| ChunkMesher
	PlayerController -->|Manipulates| IInventory
	PlayerController -->|Instantiates declarative| PlayerHUD
	VoxelInteraction -->|Delegates progress cracks to| BlockCracking
	NPCAI -->|Delegates un-throttled movement to| NPCObstacle
	NPCAI -->|Delegates tasks decisions to| IAIBehavior
	PassiveEntity -->|Delegates floating billboarding to| EntityUI
	DiskWorldRepo -->|Implements| WorldRepository
	DiskWorldRepo -->|Queries save paths from| SavePath
	SkeletalVisual -->|Sanitizes FBX structures via| Sanitizer
```

1. **The Domain Layer (`src/Domain/`):** Contains the core business rules of Dolores. It has zero dependencies on Godot's SceneTree, viewport layouts, or Vulkan rendering servers.
   * **Aggregates & Entities:** `WorldState.gd` (Aggregate Root managing chunk modifications), `Chunk.gd` (Voxel Grid), `VoxelEntity.gd` (Logical health rules), and `Quest.gd` (Logical quest representation).
   * **Value Objects:** `BlockDefinition.gd` (Immutable block traits and procedural fallback colors) and `Recipe.gd` (Encapsulates required inputs and output attributes for crafting).
   * **Domain Services:** `TradingService.gd` (Decoupled inventory transaction rules), `BiomeService.gd` (Dynamic biome routing), `StructureLibrary.gd` (Blueprint routing), `QuestService.gd` (Decoupled quest state coordinator), `VoxelNavigationService.gd` (3D A* graph network coordinator), `VillageReputationService.gd` (Player karma tracker), and `CraftingService.gd`.
   * **Interfaces & Strategies:** `IInventory.gd` (Segregated inventory contract supporting item-ID stacking queries), `IWorldModifier.gd` (World interaction bridge), `IAIBehavior.gd` (Polymorphic AI contract), and `IStructureBlueprint.gd` (Polymorphic landscaping contract).

2. **The Infrastructure Layer (`src/Infrastructure/`):** Concrete implementations of hardware-bound or framework-bound systems.
   * **Rendering & Materials (`src/Infrastructure/Rendering/`):** `ChunkNode.gd` segments rendering transforms into individual, block-type MultiMesh nodes, applying PBR materials and custom GPU shaders. `ChunkMesher.gd` manages the geometric extraction of liquid and non-cubic custom meshes. `ChunkManagerService.gd` controls multithreading and Node Object Pools. `GLBModelSanitizer.gd` recursively prunes Blender camera/light nodes and overrides PBR material parameters to prevent C++ engine warnings.
   * **Physics & Interactions (`src/Infrastructure/Player/`):** `PlayerController.gd` (First-person motion physics presenter), `VoxelInteractionComponent.gd` (Raycast solver and block placer), and `BlockCrackingVisuals.gd` (Manages unshaded cracking mesh overlays and progressive damage textures).
   * **Life & AI (`src/Infrastructure/Life/`):** `NPCAIComponent.gd` (Sensory AI brain managing task timers), `NPCObstacleSteering.gd` (Coordinates 3D whisker raycasting and step-climbing jumps), and `EntityUIComponent.gd` (Manages floating Label3D nameplates and dialogue bubbles).
   * **Persistence (`src/Infrastructure/Persistence/`):** `DiskWorldRepository.gd` implements JSON delta serialization, querying file paths from the static Value Object `SavePathConfiguration.gd` and formatting layout packing via `VoxelSaveSerializer.gd`.
   * **Audio (`src/Infrastructure/Audio/`):** `AudioService.gd` manages soundtrack crossfading and observer-driven 3D positional OGG sound effects.

3. **The Core/Bootstrap Layer (`src/Core/Bootstrap`):**
   * Acts as the **Composition Root**. It instantiates the required database repositories, configures environment nodes, registers biomes/structures, and injects loose dependencies during scene transitions. `EntityPreloaderRegistry.gd` preloads all 3D assets in RAM at boot to prevent in-game disk I/O lag spikes.

---

## 🛡️ SOLID Software Engineering Compliance

The architecture of CraftDomain is highly optimized to comply with the five SOLID software engineering design principles:

### 1. Single Responsibility Principle (SRP)
Every class has a single, strictly defined responsibility, and therefore only one reason to change.
* **`WorldController.gd`:** Offloaded from physical and visual meshing calculations. It acts strictly as an asynchronous coordinator for chunk I/O and thread scheduling, delegating 3D matrix grouping to the stateless `ChunkVisualBuilder.gd` and saving pipelines to `WorldPersistenceService.gd`.
* **`PlayerController.gd`:** Responsible *only* for movement physics, camera input handling, and velocity calculations. It delegates all raycasting, block mining, building, eating, and combat actions to `VoxelInteractionComponent.gd`.
* **`PassiveEntity.gd`:** Purified to handle strictly physical translations, gravity, and lifecycles. It delegates all floating UI billboards, Nameplates, and SpeechBubbles to `EntityUIComponent.gd`.
* **`VoxelInteractionComponent.gd`:** Focuses exclusively on Raycast solving and item placements, delegating 3D cracking mesh overlays to `BlockCrackingVisuals.gd`.
* **`NPCAIComponent.gd`:** Acts as the AI sensory brain, managing task timers, scheduling, and active behaviors, delegating 3D whisker steering and step-climbing to `NPCObstacleSteering.gd`.

### 2. Open-Closed Principle (OCP)
*Classes are open for extension, but closed for modification.*
CraftDomain utilizes data-driven registry, loading, and strategy patterns to ensure new content can be added without modifying existing code.
* **Data-Driven i18n Translations:** The engine dynamically loads translation data from `assets/translations/en.json` and `es.json`. Dialogue trees, item names, UI headers, and even floating speech bubbles are parsed using localization keys without hardcoding raw text in the controllers.
* **100% Compiled Procedural Blueprints:** Obsolete JSON structures have been completely replaced. Natural flora, retro warp pipes, mine pillars, and market cabins are registered as OCP compiled strategy scripts (`IStructureBlueprint.gd`) executing directly in RAM at zero startup I/O cost.
* **Dynamic Streetlight Themes:** `StreetlightEntity.gd` is agnostic of specific biome styles. It queries the active biome strategy for a custom configuration dictionary (`get_streetlight_theme()`) to paint lights and poles dynamically.

### 3. Liskov Substitution Principle (LSP)
Subclasses must be substitutable for their base classes without altering program correctness.
* Any strategy implementing `IBiome` can be processed by `BiomeService` and evaluated by `WorldGenerator` without runtime exceptions.
* Any blueprint implementing `IStructureBlueprint` (such as `WarpPipeBlueprint.gd` or `AdaptiveMinePillarBlueprint.gd`) is processed dynamically inside the meshing threads without type mismatches.
* **Fauna Segregation:** The virtual contract `_has_ui_decorations()` restricts floating speech bubbles, quest arrows, and conversation states exclusively to humanoid civilians. Wild animals return `false` on this check, avoiding redundant UI overhead and complying cleanly with LSP.

### 4. Interface Segregation Principle (ISP)
*Clients should not be forced to depend upon interfaces they do not use.*
* Instead of passing the entire `PlayerController.gd` (which contains camera vectors, physics movement, and input states) to the trading, loot drop, or crafting systems, the game defines `IInventory.gd`.
* `TradingService`, `CraftingService`, and `PassiveEntity` (NPCs) interact *only* with the abstract `IInventory` interface, completely separating transaction logic from character movement and camera physics.

### 5. Dependency Inversion Principle (DIP)
*High-level modules must not depend on low-level modules; both must depend on abstractions.*
* `WorldController.gd` (High-level coordinator) never directly instantiates or imports `DiskWorldRepository.gd` (Low-level JSON file details). Instead, it holds a reference to the abstract class `WorldRepository`.
* `VoxelInteractionComponent.gd` interacts with the world grid via an injected `IWorldModifier` adapter, preventing the Domain from coupling with concrete Godot SceneTree nodes.
* **Decoupled AI Strategy Integration:** High-level entities inject their decision-making logic dynamically into `NPCAIComponent.gd` through the `IAIBehavior` strategy interface, completely decoupling NPC physics controllers from logical routines.

---

## ⚡ High-Performance Voxel Sandbox Optimizations (120 FPS Guardrail)

Maintaining a locked, rock-solid **120 FPS frame rate** with smooth frame pacing is an absolute priority of the Dolores engine. No feature is allowed to introduce micro-stutters. We implement custom lower-level optimizations to maintain this performance:

### 1. Hybrid Instant/Threaded Mesher (120 FPS Mining)
To prevent Main Thread stutters and lag when placing or breaking blocks, CraftDomain utilizes a dual-pipeline meshing system:
* The modified chunk is rebuilt synchronously on the Main Thread (`_rebuild_chunk_instantly`), completing in less than 0.5ms to provide instantaneous physical/visual feedback.
* Any adjacent boundary chunks affected by the edit are offloaded asynchronously as high-priority tasks to background thread workers via the `WorkerThreadPool` (`_request_chunk_rebuild`), preventing rendering freezes completely.

### 2. Time-Sliced Physics Budgeting & Object Pooling
* **Dynamic Throttling:** Background threads are capped strictly to 2 during teleports or startup, leaving CPU cores free for Vulkan shader compiles.
* **Physics Budgeting:** `ChunkManagerService` compiles a maximum of 1-2 heavy concave collision bodies per frame, spreading physics registration overhead evenly and guaranteeing zero frame drops.
* **Object Pooling:** Inactive chunks are stored in `_chunk_node_pool` and recycled dynamically instead of triggering expensive Garbage Collection `queue_free()` sweeps.

### 3. Decoupled AI Strategy Pattern & Throttling
* **Strategy Pattern AI (`IAIBehavior`):** Extracted specialized entity AI routines from physical scripts into distinct strategies (e.g. `GargoyleAIBehavior`, `GoblinAIBehavior`, `AmphibiousAIBehavior`, `MinerAIBehavior`, `CatAIBehavior`, `DruidAIBehavior`). Keeping physical entities strictly focused on translations while delegating logical decisions to the Domain.
* **LOD AI Tick Rate:** AI sensory sweeps, threat scans, and pathfinding calculations scale their update intervals dynamically based on distance to the player: Close Range (<15m) updates at 20Hz, Mid Range (15-35m) at 4Hz, and Far Range (>35m) at 0.5Hz, reducing village CPU overhead by over 95%.
* **Smooth Vector Continuation:** Walk-cycle vector interpolations and local obstacle-jumping are processed every frame on the physics thread, ensuring entities continue to slide smoothly on screen even during throttled frames.
* **$O(1)$ Targeting:** Active entities scan for targets by querying Godot's C++ native group registry (`"hostiles"` and `"passives"`), eliminating the performance spikes of old $O(N)$ child-scanning loops.

### 4. Compile-Free Unshaded Particles & Safe Shutdowns
* To prevent dynamic Vulkan pipeline compilations (which drop FPS down to single digits during block mining), mining debris has been migrated to `CPUParticles3D` using `SHADING_MODE_UNSHADED` materials. This runs entirely on the CPU at zero compile cost.
* **Memory-Safe Timers:** All temporary particle timers connect their `timeout` signals directly to `particles.queue_free` instead of compiling dynamic lambda captures, permanently preventing `Lambda capture at index 0 was freed` memory leaks upon world exit.

### 5. Opaque Far-LOD Culling, Unified Meshing & Normal Baking
* **Alpha-Blend Bypass:** Distant chunks automatically switch translucent materials (Water, Glass, Clouds, Ice) to `TRANSPARENCY_DISABLED`. This bypasses expensive depth-sorting and alpha-blending passes on the GPU horizon, saving massive pixel fillrate overhead.
* **Sub-pixel Hermetic Sealing:** Transparent liquid and slab vertices are mathematically scaled outward from their center by a factor of `1.002` (2 millimeters). This tightly overlaps chunk borders, perfectly fixing all Z-fighting and Z-clipping leaks.
* **Unified Mesh Baker (`ChunkMesher`):** Dispatches water, lava, and stone slab meshes inside a high-performance single-pass loop. Pre-bakes physical face normals (`generate_normals()`) on the CPU before committing buffers, securing proper PBR specularity and enabling precise vertex-wave displacement (`NORMAL.y > 0.5`) in GPU shaders.

---

## ⌨️ Controls Reference

* **`W`, `A`, `S`, `D` or Arrow Keys:** Move around.
* **Mouse Movement:** Look around (Smooth camera rotation processed inside `_unhandled_input` to match high-refresh monitor rates).
* **`Space`:** Jump.
* **`M`:** Open Fullscreen Tactical Map & Fast Travel.
* **`I` (or clicking the HUD 🎒 button):** Toggle the 24-slot Backpack Inventory & Inspector overlay.
* **`C` (or clicking the HUD 🛠️ button):** Toggle the Context-aware Crafting & Blueprint Workshop.
* **`Left Alt` (Hold):** Release the captured mouse cursor to click HUD shortcut buttons.
* **Mouse Scroll Wheel or Keys `1` to `8`:** Scroll through Hotbar slots.
* **Left-Click (or `E`):** Mine blocks (generating color-matched voxel debris particles) or swing the active weapon.
* **Right-Click (or `Q`):** Place blocks, plant seeds, consume items, or interact (Talking with villagers/guards/miners/wells).
* **`Escape`:** Unlocks mouse cursor, pauses game, and triggers a silent background auto-save.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
