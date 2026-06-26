# CraftDomain

![MainMenu Background](src/Infrastructure/UI/Assets/menu_background.png)

A high-performance, infinite voxel sandbox game engine built in **Godot 4.6.3** adhering to **Domain-Driven Design (DDD)** principles and strict **SOLID** software engineering compliance. Architected to demonstrate highly decoupled, modular, and extensible systems without sacrificing runtime execution speed.

---

## Architectural Philosophy: Domain-Driven Design (DDD)

CraftDomain is architected using **Domain-Driven Design (DDD)**. By segregating the codebase into distinct layers, we isolate pure business rules (the "Domain") from framework-specific engine details (the "Infrastructure"), such as Vulkan rendering, physics colliders, and disk I/O.

### Layer Segmentation & Dependency Flow

```mermaid
graph TD
	subgraph Core_Bootstrap [Core / Bootstrap Layer]
		Bootstrap[Bootstrap.gd - Composition Root]
	end

	subgraph Infrastructure_Layer [Infrastructure Layer]
		WorldController[WorldController.gd]
		ChunkNode[ChunkNode.gd - MultiMesh]
		PlayerController[PlayerController.gd - Physics]
		DiskWorldRepository[DiskWorldRepository.gd - JSON I/O]
		DialogueManager[DialogueManager.gd]
		WeatherService[WeatherService.gd - Particles]
	end

	subgraph Domain_Layer [Domain Layer]
		WorldState[WorldState.gd - Aggregate Root]
		Chunk[Chunk.gd - Voxel Grid]
		VoxelEntity[VoxelEntity.gd - Health & Combat]
		IBiome[IBiome.gd - Strategy Interface]
		IInventory[IInventory.gd - Interface Segregation]
		QuestService[QuestService.gd - Domain Quest State]
		DialogueService[DialogueService.gd - Dialogue Router]
	end

	Bootstrap -->|Injects Repositories & Controllers| WorldController
	Bootstrap -->|Registers| IBiome
	WorldController -->|Queries & Updates| WorldState
	WorldState -->|Contains| Chunk
	ChunkNode -->|Renders| Chunk
	PlayerController -->|Manipulates| IInventory
	DiskWorldRepository -->|Implements| WorldRepository
	DialogueManager -->|Queries| DialogueService
```

1. **The Domain Layer (`src/Domain/`):** Contains the core business logic. It has zero dependencies on Godot's scene tree, physics servers, or rendering API. It consists of:
   * **Aggregates & Entities:** `WorldState.gd` (Aggregate Root managing chunks), `Chunk.gd` (Voxel Grid), `VoxelEntity.gd` (Logical health rules), and `Quest.gd` (Logical quest representation).
   * **Value Objects:** `BlockDefinition.gd` (Immutable block traits and procedural color definitions).
   * **Domain Services:** `TradingService.gd` (Decoupled inventory transaction rules), `BiomeService.gd` (Dynamic biome routing), `StructureLibrary.gd` (Blueprint routing), and `QuestService.gd` (Decoupled quest state coordinator).
   * **Interfaces:** `IInventory.gd` (Segregated inventory contract) and `WorldRepository.gd` (Persistence contract).

2. **The Infrastructure Layer (`src/Infrastructure/`):** Concrete implementations of hardware-bound or framework-bound systems.
   * **Rendering (`src/Infrastructure/Rendering/`):** `ChunkNode.gd` segments rendering transforms into individual, block-type MultiMesh nodes, applying PBR materials and custom GPU shaders.
   * **Physics (`src/Infrastructure/Player/`):** First-person motion physics, gravity solvers, and collision shapes.
   * **Persistence (`src/Infrastructure/Persistence/`):** `DiskWorldRepository.gd` implements JSON delta serialization inside Godot's safe `user://` directory.
   * **Life (`src/Infrastructure/Life/`):** Physics-bound passive and hostile AI, rendering programmatic 3D box-composition models.

3. **The Core/Bootstrap Layer (`src/Core/Bootstrap`):**
   * Acts as the **Composition Root**. It instantiates the required database repositories, configures environment nodes, registers biomes/structures, and injects loose dependencies during scene transitions, ensuring no circular compiler loops exist.

---

## SOLID Software Engineering Compliance

The architecture of CraftDomain is highly optimized to comply with the five SOLID software engineering design principles:

### 1. Single Responsibility Principle (SRP)
Each class has a single, strictly defined reason to change:
* **`PlayerController.gd`:** Responsible *only* for first-person movement physics and camera rotation. It contains no raycasting or block interaction logic.
* **`VoxelInteractionComponent.gd`:** Attached to the camera, this component has the single responsibility of managing raycast gaze selection, targeted highlighting, mining blocks, placing blocks, eating consumables, and interacting with NPCs.
* **`EnvironmentBuilder.gd`:** Responsible *only* for building and configuring the `WorldEnvironment` and `SunLight` nodes.

### 2. Open-Closed Principle (OCP)
*Classes are open for extension, but closed for modification.*
CraftDomain utilizes data-driven registry and loading patterns to ensure new content can be added without modifying existing code.

#### The Data-Driven Quest & Campaign System
Instead of hardcoding quests inside scripts, the system reads from external JSON quest configuration files.

```mermaid
sequenceDiagram
	participant Boot as Bootstrap
	participant Reg as CampaignRegistry
	participant Serv as QuestService
	participant HUD as PlayerHUD
	
	Boot->>Reg: initialize_campaign()
	Note over Reg: Scans assets/quests/ for .json files
	Reg->>Reg: Parse JSON Quest Packs
	loop For Each Quest Object
		Reg->>Serv: register_quest(Quest)
	end
	Reg->>Serv: set_active_quest("lost_bazaar")
	Serv->>HUD: Broadcast Active Quest Update
	Note over HUD: Render Quest Tracker Panel & Minimap Gold Marker
```

To add more quests (even up to 50+), a developer simply drops a new JSON file (e.g., `res://assets/quests/sidequests.json`) into the directory. The `CampaignRegistry` dynamic directory scanner automatically parses and registers it at startup without modifying a single line of GDScript.

### 3. Liskov Substitution Principle (LSP)
Subclasses must be substitutable for their base classes without altering program correctness:
* Any strategy implementing `IBiome` can be processed by `BiomeService` and evaluated by `WorldGenerator` without runtime exceptions.
* `DiskWorldRepository` inherits from `WorldRepository`, satisfying all contract signatures safely.
* Passive entities (`VillagerEntity`, `MerchantEntity`, etc.) inherit from `PassiveEntity`, implementing their custom shapes and behaviors polymorphically.

### 4. Interface Segregation Principle (ISP)
*Clients should not be forced to depend upon interfaces they do not use.*
* Instead of passing the entire `PlayerController.gd` (which contains camera vectors, physics movement, and input states) to the trading or loot drop systems, the game defines `IInventory.gd`.
* `TradingService` and `PassiveEntity` (NPCs) interact *only* with the `IInventory` interface, completely separating transaction logic from character movement and camera physics.

### 5. Dependency Inversion Principle (DIP)
*High-level modules must not depend on low-level modules; both must depend on abstractions.*
* `WorldController.gd` (High-level coordinator) never directly instantiates or imports `DiskWorldRepository.gd` (Low-level JSON file details).
* Instead, it holds a reference to the abstract class `WorldRepository`. The concrete `DiskWorldRepository` is instantiated and injected externally by `Bootstrap.gd` during boot.

---

## High-Performance Game Engine Optimizations

Voxel sandbox games are traditionally notorious for CPU and GPU bottlenecks. CraftDomain implements custom lower-level optimizations to maintain solid framerates:

### 1. Multi-Mesh Partitioned Rendering (Water Transparency Fix)
To support translucent, highly reflective water and glowing lava, `ChunkNode.gd` does not render a chunk using a single monolithic MultiMesh. Instead, it partitions chunk voxel arrays by their `BlockType` and instantiates a separate `MultiMeshInstance3D` for each active block type. This allows applying specialized materials:
* **Water Material:** Translucent blue color, roughness `0.05` (highly glossy) to enable beautiful Screen Space Reflections (SSR).
* **Lava Material:** Emission-enabled orange-red glow with a `1.8` multiplier.
* **Solid Blocks:** Use OCP-compliant custom PBR textures.

### 2. Custom GPU Blending & Triplanar Shader
Using custom PNG textures (especially AI-generated ones) on voxels often results in two common rendering artifacts: vertical texture stretching (due to BoxMesh proportions) and solid black blocks (due to transparent alpha channels exporting as black on opaque materials). 
CraftDomain implements a custom **GPU Blending Triplanar Shader** in `ChunkNode.gd` that resolves both issues:
* **Decal Triplanar Projection:** Projects textures from X, Y, and Z axes based on local vertex positions, ensuring perfectly square, non-stretched pixel mapping on all 6 faces of the cube.
* **Alpha Blending Fallback:** Automatically blends the texture colors with the block's base procedural fallback color using the texture's alpha channel. If a pixel is transparent, it renders the rich biome-specific color instead of turning black.

### 3. Static Texture Preloader (Lag Spike Prevention)
Decoding high-resolution (1024x1024) PNG files on the main thread during real-time chunk loading causes massive CPU stalls (600ms+), resulting in physics tunneling where players fall through the world. 
CraftDomain utilizes a **Static Preloader** in `ChunkNode.gd` that reads, caches, and compiles all custom textures into GPU memory *once* during game boot, keeping the gameplay completely stutter-free.

---

## Dynamic Weather & Atmospheric Cycles

The world features an integrated celestial and climatological loop coordinating sun, moon, and weather states:

```mermaid
graph LR
	subgraph Weather_Engine [Climatology & Weather]
		WeatherService[WeatherService.gd - Loop]
		RainParticles[GPUParticles3D - Rain]
		SnowParticles[GPUParticles3D - Snow]
	end

	subgraph Celestial_Engine [Day/Night Cycle]
		CelestialService[CelestialService.gd - Loop]
		SunLight[SunLight - DirectionalLight3D]
		MoonLight[MoonLight - DirectionalLight3D]
	end

	subgraph Domain_Services [Biome Coordinator]
		BiomeService[BiomeService.gd]
	end

	CelestialService -->|Rotates & Fades| SunLight
	CelestialService -->|Rotates & Fades| MoonLight
	WeatherService -->|Queries Player Coordinates| BiomeService
	BiomeService -->|Returns Biome ID| WeatherService
	WeatherService -->|If Glaciers / Cloud| SnowParticles
	WeatherService -->|If Other Biomes| RainParticles
```

### 1. The 28-Day Lunar Phase Cycle
`CelestialService.gd` manages a dynamic 28-day calendar. It instantiates a secondary `MoonLight` (`DirectionalLight3D`) opposite to the Sun, casting soft silver-blue nighttime shadows. The moonlight intensity scales dynamically on a 0.0 to 1.0 curve based on the current calendar day:
* **Day 14 (Full Moon):** Maximized silver-blue light casting bright nighttime shadows.
* **Day 1 / 28 (New Moon):** Pitch-black night.
* The current phase name (e.g., `WAXING CRESCENT`, `FULL MOON`) is displayed in real-time on the top GPS HUD.

### 2. Regional Climatology
`WeatherService.gd` manages dynamic weather shifts (Sunny, Rainy, Snowy) that interact with regional biomes:
* **The Performance Emitter:** The particle system is positioned exactly above the player's head, ensuring it only rains/snows in their immediate vicinity, protecting GPU fillrate.
* **Dynamic Biome Detection:** If precipitation begins and the player is in `Frostbite Glaciers` (Biome 4) or `Cloud Kingdom` (Biome 9), the system automatically alters the particle mesh to slowly drifting, wind-blown white snowflakes. In other biomes, it falls as fast, translucent blue rain needles.

---

## Decoupled SOLID UI Architecture

To satisfy the Single Responsibility Principle, the original `PlayerHUD` was fully refactored. Instead of acting as a monolithic interface, `PlayerHUD.gd` acts as a lightweight **UI Composition Root** managing independent, decoupled sub-widgets:

* **`MinimapWidget.gd`:** Renders the 2D circular radar, the player's white arrow with a thick black outline, and the active quest's pulsing hot-pink navigation diamond (designed to clamp to the compass rim when far away).
* **`GPSPanelWidget.gd`:** Displays coordinates, the celestial clock, active region biome, and cardinal landmark distances.
* **`QuestTrackerWidget.gd`:** Renders active quest descriptions, remaining distance in meters, and altitude/gathering progress.

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
    │   ├── Dialogue           # Pure dialogue data nodes
    │   ├── Life               # Pure domain models (Combat state, health limits)
    │   ├── Player             # Segregated IInventory interfaces
    │   ├── Quest              # Pure quest entities and domain coordinators
    │   └── World              # Strategy patterns (IBiome, Blueprints, Block Definitions)
    └── Infrastructure
        ├── Audio              # Programmatic loops and parallel crossfaders
        ├── Celestial          # Day/night orbits and Weather particle generators
        ├── Dialogue           # Dialogue manager and UI adapters
        ├── Life               # Physics controllers, NPCs, blinking, and spawning
        ├── Persistence        # Safe JSON save delta serializers
        ├── Player             # FP controllers, viewmodels, and interaction components
        ├── Rendering          # MultiMesh chunk nodes and custom GPU shaders
        └── UI                 # Glassmorphic sub-widgets, compasses, and pause overlays
```

---

## Controls Reference

* **`W`, `A`, `S`, `D` or Arrow Keys:** Move around.
* **Mouse Movement:** Look around (Smooth camera rotation processed inside `_unhandled_input` to match high-refresh monitor rates).
* **`Space`:** Jump.
* **Mouse Scroll Wheel or Keys `1` to `8`:** Scroll through Hotbar slots:
  * `1` (Stone), `2` (Dirt), `3` (Grass), `4` (Wood), `5` (Leaves), `6` (Lava Bucket), `7` (Fried Chicken), `8` (Sword).
* **Left-Click (or `E`):** Mine blocks or swing the active weapon.
* **Right-Click (or `Q`):** Place blocks, consume items (eating Fried Chicken to heal), or interact (trading with the Purple-Robed Merchant, talking to villagers).
* **`Escape`:** Unlocks mouse cursor, pauses game, and triggers a silent background auto-save.

---

## License

This project is licensed under the MIT License.
