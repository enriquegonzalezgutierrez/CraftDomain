# CraftDomain - Architectural Expansion Roadmap
*Future systems design written by Enrique González Gutiérrez (enrique.gonzalez.gutierrez@gmail.com)*

This roadmap outlines the technical blueprint and system designs required to expand **CraftDomain** into an immersive, RPG-capable voxel sandbox engine. Every system is structured following **Domain-Driven Design (DDD)** and **SOLID** principles to ensure seamless extensibility.

---

## Core Architectural Axioms: Preserving DDD & SOLID

To prevent the engine from collapsing into a monolithic, tightly coupled "spaghetti" codebase as features are added, future developers must strictly adhere to these architectural guidelines. **Extending the game must always be achieved by writing NEW files, never by modifying existing core controllers.**

### 1. Pure Domain Isolation (DDD Compliance)
*   **The Domain is Independent:** The directories inside `src/Domain/` represent pure business rules and mathematics. They must have **zero dependencies** on Godot nodes, scene trees, Vulkan rendering meshes, or physical colliders.
*   **Decouple via Contracts:** If a domain service needs to interact with persistence or engine hardware, define an interface/contract inside the Domain (e.g., `WorldRepository.gd`), and implement the concrete logic inside `src/Infrastructure/`.

### 2. The Open-Closed Principle (OCP) as a Law of Extension
*   **No Core Loop Modifications:** Core managers—such as `WorldGenerator.gd`, `WorldController.gd`, and `ChunkNode.gd`—are **closed to modifications**.
*   **Extend via Strategy Registries:** Adding new elements (such as Volcano Biomes, Cyber Castles, or Blacksmith NPCs) must be done by subclassing abstract interfaces (`IBiome`, `IStructureBlueprint`, `IInventory`, `DialogueNode`) and registering them dynamically inside `Bootstrap.gd`.
*   **Anti-Pattern Warning:** Never use large `match` or `if/else` statements inside core carvers to evaluate specific biomes or structural IDs. Doing so violates OCP, leading to endless file merge conflicts and compile-time fragility.

---

## Technical Architecture Overview

```
					  [ Player Interaction Raycast ]
									|
									v
	 [ Dialogue Engine ] <=====================> [ Quest Manager ]
			 |                                          |
			 v (Choice HUD / 3D Billboards)             v (Objective Tracker)
   [ Presentation Layer ]                       [ Persistence Layer ]
```

---

## Phase 1: Branching Dialogue & 3D Speech Bubbles

To transform NPCs from static vendors into narrative characters, we must implement a modular dialogue system capable of branching choices and real-time atmospheric rendering.

### 1. Dialogue Node Resource (`res://src/Domain/Dialogue/DialogueNode.gd`)
Dialogue is represented as a tree structure of immutable, reusable Resource files. This separates dialogue text from the NPC entity logic:

```gdscript
class_name DialogueNode
extends Resource

@export var node_id: String
@export_multiline var text: String
@export var choices: Array[DialogueChoice] = []
```

Where `DialogueChoice` is a nested sub-resource:
```gdscript
class_name DialogueChoice
extends Resource

@export var option_text: String
@export var target_node_id: String
@export var required_quest_id: String = "" # Optional condition
@export var reward_item_id: String = ""      # Optional trigger
```

### 2. Atmospheric 3D Speech Bubbles (`res://src/Infrastructure/UI/SpeechBubble.gd`)
To display brief overhead speech without pausing the game, we will add a **3D Billboard Speech Bubble** above NPCs:
* **Implementation:** Add a `SubViewport` containing a styled 2D `Panel` with a `Label` as a child of the NPC node.
* **Rendering:** Render the viewport's texture on a `Sprite3D` configured with `billboard = SpatialMaterial.BILLBOARD_ENABLED` (keeps the speech bubble facing the player's camera at all times).
* **Usage:** Used for floating greetings, short alerts, and vendor barks.

### 3. Fullscreen Interactive Choice HUD (`res://src/Infrastructure/UI/DialogueOverlay.gd`)
When the player triggers a deep dialogue node (e.g., accepting a quest):
1. Lock player movement input and free the mouse cursor.
2. Slowly tilt the camera toward the NPC's face.
3. Bring up a glassmorphic bottom-screen container showing the NPC's text and a list of interactive buttons for player choices.
4. Clicking a choice evaluates the target `node_id`, updating the dialogue overlay or triggering game state events (e.g., adding a quest to the journal).

---

## Phase 2: Decoupled Quest Engine

The Quest system must remain entirely independent of physical entity controllers, operating purely on logical conditions.

### 1. Domain Models (`res://src/Domain/Quest/`)
* **`QuestDefinition.gd`:** Value object storing static quest data:
  ```gdscript
  class_name QuestDefinition
  extends RefCounted
  
  var id: String
  var title: String
  var description: String
  var objective_type: String # "KILL", "GATHER", "SPEAK"
  var target_id: String       # e.g., "Entity_ZOMBIE" or "Stone"
  var required_amount: int
  ```
* **`QuestState.gd`:** Entity tracking the active progress of a quest for the player:
  ```gdscript
  class_name QuestState
  extends RefCounted
  
  var quest_id: String
  var current_amount: int = 0
  var is_completed: bool = false
  ```

### 2. Infrastructure Quest Manager (`res://src/Infrastructure/Quest/QuestManager.gd`)
A singleton global service that acts as an event router:
* Listens to logical event signals: `block_mined(type)`, `enemy_slain(entity_name)`, or `npc_interacted(npc_id)`.
* Iterates through the player's active `QuestState` list, increments the counters when matches are found, and triggers HUD achievements when objectives are completed.

### 3. Quest Persistence Integration
* **Serialization:** Upgrades `DiskWorldRepository.gd`'s `save_global_state()` to serialize the player's active `QuestState` array into `global_save.json` alongside their position and inventory quantities.

---

## Phase 3: Expanded NPC Roles & Faction AI

To make the villages feel alive and dynamic, we will expand `PassiveEntity` behaviors and introduce defensive AI:

```
        [ Faction: Village ]                 [ Faction: Undead ]
                 |                                    |
                 v                                    v
     [ Guard NPC / Farmer NPC ] <=== Combat ===> [ Zombie / Skeleton ]
```

### 1. The Guard NPC (`res://src/Infrastructure/Life/GuardEntity.gd`)
A combat-oriented village protector node:
* **Sensors:** Features an `Area3D` spherical sensor scanning for hostiles (`HostileEntity`) within a 12-meter radius.
* **Movement:** Patrolls a procedural path around village cabins when peaceful.
* **Combat:** If a Zombie is detected, the Guard switches its AI state to `ENGAGING`, unsheathes a programmatic voxel sword, runs to the hostile, and swings to attack, absorbing aggro away from players and passive villagers.

### 2. The Farmer NPC (`res://src/Infrastructure/Life/FarmerEntity.gd`)
A dedicated resource-gathering villager:
* **Tending Fields:** Periodically wanders towards nearby crop blocks or mud areas.
* **Task Cycle:** Performs the `EXAMINING` state to tap on blocks, simulating harvesting.
* **Inventory Deposit:** Walks back to village cabins to "deposit" resources inside wood barrels (modifying coordinate metadata), visualising a real working economy.

---

## Development Milestones Roadmap

### Phase 1: Interface & Core Dialogue (Laying the Groundwork)
* [ ] Implement `IInventory` upgrades to support custom quest items.
* [ ] Implement `IStructureBlueprint` for a Dedicated Village Tavern.
* [ ] Code the `get_formatted_time()` integration to trigger night shifts accurately.

### Phase 2: Dialogue & Quests Integration
* [ ] Code `IBiome` coordinate-mapping logic to spawn specific quest-giving NPCs in predetermined regions (e.g., Ice Spires spawning Ice priests).
* [ ] Write the Dialogue Tree parser with multiple-choice buttons inside the HUD.
* [ ] Integrate the overhead 3D Billboard Speech bubble above active NPCs.

### Phase 3: Active AI & Combat Expansion
* [ ] Implement the `GuardEntity` with hostile sensor arrays and melee combat behaviors.
* [ ] Introduce skeleton archers (firing programmatic 3D arrow projectiles) to challenge village defenses during midnight cycles.
* [ ] Add the Farmer NPC crop harvesting behaviors.
