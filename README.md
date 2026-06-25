# CraftDomain

![MainMenu Background](src/Infrastructure/UI/Assets/menu_background.png)

A high-performance, infinite voxel sandbox game engine built in **Godot 4.6.3** adhering to **Domain-Driven Design (DDD)** principles and strict **SOLID** software engineering compliance. Crafted to demonstrate decoupled, modular, and highly extensible systems without sacrificing runtime execution speed.

---

## Architectural Philosophy: Domain-Driven Design (DDD)

CraftDomain is architected using **Domain-Driven Design (DDD)**. By segregating the codebase into distinct layers, we isolate pure business rules (the "Domain") from the framework-specific engine details (the "Infrastructure"), such as Vulkan rendering, physics colliders, and disk I/O.

```
	   [ Core / Bootstrap ]  <-- Application Entry & Dependency Injection
			   |
			   v
	 [ Infrastructure Layer ] <-- Godot Nodes, Vulkan MultiMeshes, Physics Server, Disk I/O
			   |
			   v
	   [ Domain Layer ]       <-- Pure Mathematics, Entities, Aggregates, Strategy Interfaces
```

### Layer Segmentation:
1. **The Domain Layer (`src/Domain/`):** Contains the core business logic. It has zero dependencies on Godot's scene tree, physics servers, or rendering API. It consists of:
   * **Aggregates & Entities:** `WorldState.gd` (Aggregate Root managing chunks), `Chunk.gd` (Voxel Grid), and `VoxelEntity.gd` (Logical health and survival rules).
   * **Value Objects:** `BlockDefinition.gd` (Immutable block traits and procedural color definitions).
   * **Domain Services:** `TradingService.gd` (Decoupled inventory transaction rules), `BiomeService.gd` (Dynamic biome routing), and `StructureLibrary.gd` (Blueprint routing).
   * **Interfaces:** `IInventory.gd` (Segregated inventory contract) and `WorldRepository.gd` (Persistence contract).

2. **The Infrastructure Layer (`src/Infrastructure/`):** Concrete implementations of hardware-bound or framework-bound systems.
   * **Rendering (`src/Infrastructure/Rendering/`):** `ChunkNode.gd` maps pre-compiled visual float buffers directly into Godot's GPU-bound Vulkan pipeline.
   * **Physics (`src/Infrastructure/Player/`):** First-person motion physics, gravity solvers, and collision shapes.
   * **Persistence (`src/Infrastructure/Persistence/`):** `DiskWorldRepository.gd` implements JSON delta serialization inside Godot's safe `user://` directory.
   * **Life (`src/Infrastructure/Life/`):** Physics-bound passive and hostile AI, rendering programmatic 3D box-composition models.

3. **The Core/Bootstrap Layer (`src/Core/Bootstrap`):**
   * Acts as the **Composition Root**. It instantiates the required database repositories, configures environment nodes, and injects loose dependencies during scene transitions, ensuring no circular compiler loops exist.

---

## SOLID Software Engineering Compliance

The architecture of CraftDomain is heavily optimized to comply with the five SOLID software engineering design principles:

### 1. Single Responsibility Principle (SRP)
Each class has a single, strictly defined reason to change:
* **`WorldGenerator.gd`:** Responsible *only* for procedural noise evaluations and coordinate carving. It contains no physics or rendering code.
* **`ChunkNode.gd`:** Responsible *only* for binding GPU MultiMesh transforms and managing collision shapes.
* **`MobSpawningService.gd`:** Responsible *only* for finding valid coordinate heights and instantiating NPCs.

### 2. Open-Closed Principle (OCP)
*Classes are open for extension, but closed for modification.*
CraftDomain avoids large `match` or `if/else` statements for biomes and structures. Instead, it utilizes dynamic strategy registries:

* **Extending Biomes:** To add a new biome, you implement `IBiome.gd` (e.g., `VolcanoBiome.gd`) and register it inside `Bootstrap.gd` via `BiomeService.register_biome()`. You do not modify `BiomeService.gd` or `WorldGenerator.gd` to introduce new terrain types.
* **Extending Structures:** To introduce a new tree or building, you implement `IStructureBlueprint.gd` and register it via `StructureLibrary.register_blueprint()`. The terrain carver imports and draws it polimorphically.

```
 [ IBiome Strategy ] <--- Inherits --- [ OakMeadowBiome ] (New Biome)
         |
         v (Registered dynamically via Bootstrap)
 [ BiomeService Registry ] <--- Queried by --- [ WorldGenerator ] (Closed to edits)
```

### 3. Liskov Substitution Principle (LSP)
Subclasses must be substitutable for their base classes without altering program correctness:
* Any strategy implementing `IBiome` can be processed by `BiomeService` and evaluated by `WorldGenerator` without runtime exceptions.
* `DiskWorldRepository` inherits from `WorldRepository`, satisfying all contract signatures safely.

### 4. Interface Segregation Principle (ISP)
*Clients should not be forced to depend upon interfaces they do not use.*
* Instead of passing the entire `PlayerController.gd` (which contains camera vectors, physics movement, and input states) to the trading system, the game defines `IInventory.gd`.
* `TradingService` and `PassiveEntity` (Villagers) interact *only* with the `IInventory` interface, completely separating transaction logic from character movement and camera physics.

### 5. Dependency Inversion Principle (DIP)
*High-level modules must not depend on low-level modules; both must depend on abstractions.*
* `WorldController.gd` (High-level coordinator) never directly instantiates or imports `DiskWorldRepository.gd` (Low-level JSON file details).
* Instead, it holds a reference to the abstract class `WorldRepository`. The concrete `DiskWorldRepository` is instantiated and injected externally by `Bootstrap.gd` during boot.

---

## High-Performance Game Engine Optimizations

Voxel sandbox games are traditionally notorious for single-threaded CPU bottlenecks. CraftDomain implements custom lower-level optimizations to maintain solid framerates:

### 1. Atomic MultiMesh GPU Swapping (Rendering Fix)
In Godot 4, modifying a `MultiMesh`'s `instance_count` and `buffer` in-place on an active, already-rendered instance often fails to force a GPU buffer re-allocation. This results in newly placed blocks being logically present but completely invisible.
* **The Optimization:** `ChunkNode.gd` implements an **Atomic Swap** of the `MultiMesh` object inside `setup_chunk_visuals()`. When a block is broke or placed, the engine instantiates a clean `MultiMesh` in memory, flushes the binary transform buffer, and swaps the reference in a single atomic instruction (`0.01ms`), forcing Vulkan to immediately draw the updated geometry.

### 2. Main-Thread Physics Synchronization (Crash Prevention)
Instantiating `StaticBody3D` nodes, creating shape owners, and registering colliders on background threads is not thread-safe and causes race conditions in Godot's `PhysicsServer3D`, leading to silent collision dropouts where players and NPCs fall through the world.
* **The Optimization:** The heavy mathematical calculation of collecting voxel surface transforms is offloaded entirely to background worker threads (`WorkerThreadPool`). However, the actual instantiation of the `StaticBody3D` and the registration of its shape owners are queued and executed on the **Main Thread** during frame rendering (`0.1ms` cost). This guarantees uncorrupted colliders while preserving multi-threaded generation.

### 3. Self-Healing On-Demand Generation
Because chunk loading is asynchronus, a player could theoretically place a block in a coordinate that lies on an un-rendered vertical chunk layer (e.g., placing a block at `Y = 16` before chunk `Y = 1` finishes rendering), causing the block to be consumed but never shown.
* **The Optimization:** `WorldController.gd` implements a self-healing on-demand hook inside `set_block_globally()`. If a block is placed where no visual `ChunkNode` is currently active, the controller instantly generates the chunk logically, reads any existing disk modifications, instantiates the node, and renders it on the main thread in a single frame.

### 4. Dual-Octave Terrain Blending
To break the monotony of standard noise hills:
* The engine combines a **Macro Noise** (broad terrain geography) with a high-frequency **Micro Detail Noise** to add ridges and dunes.
* It implements **Selective Smoothing**: Mountainous biomes (like Craggy Peaks) retain sharp, rugged cliffs, while flat meadows and villages are smoothed out with a 3x3 box-blur pass to make navigation comfortable.

---

## NPC Animation & Behavior Engine

Passive entities (Villagers, Merchants, and Animals) feature custom procedural behaviors that eliminate stiff, robotic motions:

* **Procedural 3D Blinking Eyes:** NPCs feature eyes constructed of voxel boxes (sclera + pupils). A randomized timer (every 2.5 to 6 seconds) triggers a blink by scaling the eyes vertically down to `0.1` and smoothly recovering back to `1.0` using a frame-independent duration solver.
* **Organic Walk Cycles:** Movement applies sine-wave bobbing animations to the heads, arms, and body rotation, simulating natural steps.
* **Idle Work Behaviors (Farming/Inspecting):** When idle, NPCs randomly transition into an `EXAMINING` state. They stop, rotate their heads downwards toward the ground, and sway their arms vertically to simulate hoeing or inspecting soil.
* **Interactive Player Greeting:** When the player enters a 3.5-meter radius, the NPC will pause its current task, turn its face toward the player, and execute a head-nodding greeting animation.

---

## Directory Layout & Specifications

```
.
├── MANUAL.md                  # Gameplay and economic instruction manual
├── README.md                  # Technical engine documentation
├── project.godot              # Godot project settings (Physics @ 120Hz, Forward+)
└── src
    ├── Core
    │   └── Bootstrap          # Application entry-point and dependency injector
    ├── Domain
    │   ├── Life               # Pure domain models (Combat state, health limits)
    │   ├── Player             # Segregated IInventory interfaces
    │   └── World              # Strategy patterns (IBiome, Blueprints, Block Definitions)
    └── Infrastructure
        ├── Audio              # Programmatic loops and parallel crossfaders
        ├── Celestial          # Dynamic Sun rotations and color sky lerping
        ├── Life               # Physics controllers, box composition models, blinking
        ├── Persistence        # Safe JSON save delta serializers
        ├── Player             # FP controllers, mouse-motion camera, sways
        ├── Rendering          # Concave physics wrappers, MultiMesh GPU swaps
        └── UI                 # Glassmorphic compasses, minimaps, pause states
```

---

## Delta-Saving Persistence Pipeline

CraftDomain implements a high-performance, asynchronous **Delta-Saving** architecture to prevent file corruption and memory bloat:

* **Block Modifications:** The engine does not save unchanged terrain blocks. Only modified coordinates (mined or placed blocks) are tracked inside `world_state._chunk_modifications` as delta values. When a save is triggered, these deltas are stored in lightweight, independent JSON files named on a per-coordinate basis (`chunk_x_y_z.json`), making disk operations extremely fast.
* **Global Metadata:** Player coordinates, look angles, world seed, and **hotbar inventory quantities** are securely serialized into `global_save.json`.
* **Auto-Save Trigger:** Pressing `Escape` pauses the game, captures the mouse cursor, and silently executes a complete delta-save in the background without causing gameplay stutters.

---

## Controls Reference

* **`W`, `A`, `S`, `D` or Arrow Keys:** Move around.
* **Mouse Movement:** Look around (Smooth camera rotation processed inside `_unhandled_input` to match high-refresh monitor rates).
* **`Space`:** Jump.
* **Mouse Scroll Wheel or Keys `1` to `8`:** Scroll through Hotbar slots:
  * `1` (Stone), `2` (Dirt), `3` (Grass), `4` (Wood), `5` (Leaves), `6` (Lava Bucket), `7` (Fried Chicken), `8` (Sword).
* **Left-Click (or `E`):** Mine blocks or swing the active weapon.
* **Right-Click (or `Q`):** Place blocks, consume items (eating Fried Chicken to heal), or interact (trading with the Purple-Robed Merchant).
* **`Escape`:** Unlocks mouse cursor, pauses game, and triggers a silent background auto-save.

---

## License

This project is licensed under the MIT License.
