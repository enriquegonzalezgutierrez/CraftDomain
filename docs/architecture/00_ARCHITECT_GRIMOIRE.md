# Dolores - Master Software Architecture & Clean Coding Bible
*Written by Enrique González Gutiérrez (enrique.gonzalez.gutierrez@gmail.com)*

This document establishes the absolute, non-negotiable software engineering guidelines, performance parameters, and clean coding standards for the "Dolores" project. It is designed to preserve a highly decoupled, modular, testable, and long-term maintainable codebase under Godot 4.6.3. All developers, code generators, and refactoring tasks must adhere strictly to these rules.

---

## 🧭 SECTION 1: THE CORE ARCHITECTURAL MANDATE

### 1.1 Architecture Over Speed
The quality, cleanliness, and decoupling of the software architecture always take absolute priority over development speed or short-term convenience. Writing more modular, decoupled, and testable code is always preferred over writing shorter, tightly-coupled code. Under no circumstances shall architectural integrity be sacrificed to deliver a feature faster.

### 1.2 Core Metrics
Every line of code committed to this repository must strive for:
- **Maximum Cohesion:** Each class must do one thing, and do it completely.
- **Minimum Coupling:** Classes must interact through abstract interfaces, minimizing direct knowledge of other components' concrete implementations.
- **Zero Technical Debt:** Code must be refactored proactively. Speculative future features (YAGNI) or redundant abstractions are strictly forbidden.
- **High Testability:** Logic must be separated from Godot's SceneTree so it can be verified in isolation.

### 1.3 Strict 120 FPS Performance Guardrail
Maintaining a locked, rock-solid **120 FPS frame rate** with smooth frame pacing is an absolute priority of the Dolores engine. No feature, visual effect, or complex simulation algorithm shall be implemented if it introduces micro-stutters, frame drops, or causes the frame rate to fall below 120 FPS on target hardware. All rendering, thread pooling, and physics calculations must be designed with strict computational time-budgets.

---

## 🏗️ SECTION 2: LAYERED DOMAIN-DRIVEN DESIGN (DDD)

We segregate our codebase into three distinct layers with a strict one-way dependency flow. Dependencies must only point inwards (toward the Domain layer). Higher-level layers may depend on lower-level layers, but the lower-level layers must have absolute zero knowledge of the layers above them.

```
   +-------------------------------------------------+
   |              BOOTSTRAP / CORE                   |
   +-------------------------------------------------+
                            |
                            v
   +-------------------------------------------------+
   |            INFRASTRUCTURE LAYER                 |
   |   (UI, Audio, Rendering, Physics, Persistence)  |
   +-------------------------------------------------+
                            |
                            v
   +-------------------------------------------------+
   |                DOMAIN LAYER                     |
   |   (Rules of Business, Value Objects, Entities)  |
   +-------------------------------------------------+
```

### 2.1 The Domain Layer (`src/Domain/`)
The Domain layer represents the core business rules of Dolores. It is a representation of the simulation mechanics (health calculations, recipe transactions, quest state machines, navigation coordinate graphs) and must remain entirely untainted by the technical framework (Godot Engine).
- **Zero Framework Leakage:** Domain classes must have absolute zero dependencies on Godot's rendering servers, audio buses, input events, disk I/O, or viewport layouts.
- **No Node Dependencies:** Domain classes must inherit from `RefCounted` or plain objects. Inheriting from `Node`, `Node3D`, `Control`, or `CharacterBody3D` inside the Domain folder is strictly prohibited.
- **Pure Data & Logic:** This layer contains Entities (e.g., `VoxelEntity.gd`), Value Objects (e.g., `Recipe.gd`), and Pure Domain Services (e.g., `CraftingService.gd`, `VillageReputationService.gd`).

### 2.2 The Infrastructure Layer (`src/Infrastructure/`)
The Infrastructure layer contains the concrete technical implementations of the framework. It handles the physical realization of the simulation: Vulkan rendering, MultiMesh allocations, physics body collisions, disk JSON saving, audio bus playback, first-person player input, and UI layouts.
- **Separation of Concerns:** Infrastructure classes (such as `PlayerController.gd` or `MainMenu.gd`) coordinate the Godot engine state but must delegate all simulation business rules directly to the Domain layer.
- **Interface Realization:** Low-level persistent or networking systems must implement abstract interfaces declared in the Domain layer to preserve Dependency Inversion (DIP).

### 2.3 The Core/Bootstrap Layer (`src/Core/`)
The Bootstrap layer acts as the **Composition Root** of the entire application. 
- It is the only layer allowed to instantiate database repositories, load setting configurations, and inject concrete dependencies into controllers.
- It prevents circular compiler dependencies by managing the lifecycle of the system globally during scene transitions.

---

## 🛡️ SECTION 3: THE SOLID DESIGN PRINCIPLES

### 3.1 Single Responsibility Principle (SRP)
*A class must have one, and only one, reason to change.*
- If a class manages movement physics, it must not handle UI floating nameplates.
- If a class processes raycasts, it must not pre-calculate inventory item drop tables.
- **Bad Practice Example:** A `PassiveEntity.gd` script handling both gravity slide velocity and the drawing of a 3D speech bubble.
- **Good Practice Example:** Slicing the speech bubble drawing out to an independent `EntityUIComponent.gd`, leaving `PassiveEntity.gd` with the sole responsibility of translation physics and life states.

### 3.2 Open-Closed Principle (OCP)
*Software entities must be open for extension, but closed for modification.*
- You must never modify existing, verified classes to add new features. Extension must be achieved via composition, Strategy patterns, State patterns, or polymorphism.
- **Example (Biomes):** To add a new biome, you must create a new class implementing the `IBiome` interface. You must never modify `BiomeService.gd`'s core structure to add custom conditional `if/else` checks for the new biome ID.
- **Example (Block Properties):** To define a new block's physical properties (transparency, solidity, drops), create a new script inheriting from `BlockDefinition.gd` inside the `/Blocks/` folder. The `BlockLibrary` will dynamically auto-scan and register it.

### 3.3 Liskov Substitution Principle (LSP)
*Subclasses must be completely substitutable for their base classes without altering program correctness.*
- Never break contract signatures. A child class must never throw a runtime exception or return an unaligned type for a virtual method declared in the parent interface.
- **Example (Fauna UI):** Humanoid civilians can gossip and carry floating speech bubbles. Wild animals (pigs, cows, chickens) do not. Under LSP, instead of forcing animals to implement empty speech bubble methods, the base class defines `_has_ui_decorations() -> bool`. Animals return `false` on this check, cleanly segregating the UI overhead.

### 3.4 Interface Segregation Principle (ISP)
*Clients must never be forced to depend on interfaces they do not use.*
- Design small, highly specific, and cohesive interfaces instead of monolithic ones.
- **Example (`IInventory`):** Systems like `TradingService` or `CraftingService` do not need to know about the player's movement physics, active camera angles, or node hierarchy. Therefore, we define the highly segregated interface `IInventory.gd` containing only item stack queries. The trading and crafting services depend *only* on `IInventory`, separating them entirely from `PlayerController.gd`.

### 3.5 Dependency Inversion Principle (DIP)
*High-level modules and pure Domain layers must never depend on low-level infrastructure modules. Both must depend on abstract interfaces.*
- Low-level framework details (e.g. JSON saving to SSD) must depend on abstract boundaries declared in the Domain layer (e.g. `WorldRepository.gd`).
- **Example (`IWorldModifier`):** Domain item placement strategies (`PlaceableBlockStrategy.gd`) must write blocks into the world grid. To prevent the Domain from depending on the scene-tree `WorldController.gd`, we define an abstract `IWorldModifier.gd` adapter interface. The placement strategy writes blocks through this interface, keeping the Domain strictly decoupled from the concrete Godot controller.

---

## 📝 SECTION 4: STRICT CODE SIZE & COHESION LIMITS

To maintain extreme cohesion, all GDScript files must adhere strictly to these physical size limits:

### 4.1 Class Size Limits
- **Ideal Size:** 100 to 200 lines of code.
- **Maximum Absolute Limit:** 300 lines of code.
- *Any script passing the 300-line limit must be immediately decomposed into smaller, specialized sub-components.*

### 4.2 Method Size Limits
- **Ideal Size:** 5 to 10 lines of code.
- **Maximum Absolute Limit:** 20 lines of code.
- *Any function passing the 20-line limit must be immediately broken down into smaller private helper methods.*

---

## 🚫 SECTION 5: ABSOLUTE CODING PROHIBITIONS

### 5.1 Prohibited Naming Conventions
To prevent multiple responsibilities from accumulating in single classes, the compile-time registration or creation of files containing the following suffix/prefix names is **strictly prohibited**:
- `*Manager*` (e.g., `GameManager`, `ChunkManager`)
- `*Utils*` (e.g., `MathUtils`, `VoxelUtils`)
- `*Helper*` (e.g., `SaveHelper`, `UIHelper`)
- `*Common*` (e.g., `CommonVariables`)
- `*Global*` (e.g., `GlobalState`)
- `*Misc*` (e.g., `MiscFunctions`)
- `*ServiceLocator*`

*If a class requires these names, its responsibilities are ill-defined. It must be split into cohesive, Domain-friendly entities (e.g., renaming `SaveHelper` to `VoxelSaveSerializer` and `DiskWorldRepository`).*

### 5.2 Zero Hardcoded UI Strings
Writing visible raw text strings directly inside GDScript source code is **strictly forbidden**.
- **Bad:** `btn.text = "Resume Game"`
- **Good:** `btn.text = tr("HUD_PAUSE_RESUME")`
- All visible text, notifications, labels, speech bubbles, and button titles must utilize Godot's localization engine via the `tr()` function.
- All translations must be stored externally inside `assets/translations/en.json` and `es.json`.

### 5.3 Zero Magic Numbers
Statically writing raw integers, floats, or colors directly in logical statements is **strictly forbidden**.
- **Bad:** `if distance < 12.0:` or `col = Color(0.95, 0.15, 0.15)`
- **Good:** Declare them as statically typed constants or Enums at the top of the file:
  ```gdscript
  const SIGHT_RANGE_SQ: float = 144.0 # 12.0 meters squared
  const COLOR_ALERT := Color(0.95, 0.15, 0.15)
  ```

### 5.4 Zero Hardcoded File Paths
Never hardcode file paths inside local methods. Centralize them as preloaded constants at the top of the script using strict static typing:
```gdscript
const MODEL_PATH: String = "res://assets/models/decorations/barrel.glb"
```

---

## 💻 SECTION 6: GDSCRIPT 2.0 CODING STANDARDS

All GDScripts must be compiled under strict static typing. Untyped declarations or `Variant` fallbacks are prohibited unless absolutely necessary and documented.

### 6.1 Strict Static Typing
- All variables, function parameters, and return values must possess explicit static typing:
  ```gdscript
  # Correct
  var speed: float = 6.0
  var target_coord: Vector3i = Vector3i.ZERO
  
  func calculate_distance(target: Vector3) -> float:
      return global_position.distance_to(target)
  ```
- Disable untyped warnings inside `project.godot` to ensure compile-time verification:
  `gdscript/warnings/untyped_declaration=1`

### 6.2 Safe Runtime Casting
When querying nodes or resources dynamically, always execute safe casting (`as`) and verify validity before accessing properties:
```gdscript
var inventory := player.get("inventory") as InventoryComponent
if is_instance_valid(inventory):
    inventory.add_item(16, 1)
```

### 6.3 Godot Engine Methods Control
Avoid placing heavy business rules or calculations inside Godot's virtual lifecycle loops (`_ready()`, `_process()`, `_physics_process()`). These methods must act strictly as lightweight coordinators, dispatching calls to specialized, testable sub-methods:
```gdscript
# Correct
func _process(delta: float) -> void:
    _animate_spinner(delta)
    _animate_status_dots()
    _check_dismiss_condition()
```

---

## ⚡ SECTION 7: HIGH-PERFORMANCE VOXEL ENGINE OPTIMIZATIONS

Voxel sandbox games are highly sensitive to CPU and GPU fillrate bottlenecks. All infrastructure systems must implement these performance guardrails to secure a locked 120 FPS runtime execution:

### 7.1 UI Scene-Based Instantiation
- Building UI layouts, StyleBoxFlats, margins, or button grids procedurally inside GDScript is **strictly forbidden**.
- All interfaces must be constructed declaratively using Godot `.tscn` files and `.tres` Theme resources. Scripts must remain < 50 lines, handling exclusively signals and animations.
- **The .tscn First-Line Bracket Rule:** Every `.tscn` file must start *exactly* with the opening bracket `[` (e.g. `[gd_scene ...]` on Line 1). Placing comment headers `;` or whitespace before this bracket is strictly forbidden as it breaks Godot's C++ parser.

### 7.2 Throttled Metric Updates
- Updating UI labels, GPS coordinates, compass cardinal directions, or quest trackers every frame (120 FPS) is forbidden.
- All non-physics visual updates must be throttled to run exactly **20 times per second (20Hz)** using a delta accumulator timer, reducing Main Thread CPU load by over 80%.

### 7.3 Decoupled Signal-Driven Observers
- Avoid tight bindings between independent systems. Never call sibling managers directly inside local writes.
- Use Godot's C++ signals (Observer Pattern) to decouple write events. For example, when a block is broken, the `WorldController` emits the `block_modified` signal. Sibling services (such as fluid simulation, agriculture, or audio players) listen to this signal to update their states independently.

### 7.4 Compile-Free Unshaded Particles
- Spawning shaded particles during block breaking is prohibited, as it triggers expensive Vulkan pipeline compilations on the GPU, causing severe frame drops.
- Always use `CPUParticles3D` with `SHADING_MODE_UNSHADED` materials for mining debris and hits.

### 7.5 Memory-Safe Shutdowns
- To prevent memory leaks (`Lambda capture was freed` errors) during world exits, always connect temporary particle timers directly to `particles.queue_free` instead of compiling dynamic lambda captures.
- All background threads inside `ChunkManagerService.gd` must be joined and safely shut down before exiting the SceneTree.