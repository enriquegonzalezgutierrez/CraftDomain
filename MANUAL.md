# CraftDomain - Gameplay & Survival Manual
*Written by Enrique González Gutiérrez (enrique.gonzalez.gutierrez@gmail.com)*

Welcome to **CraftDomain**, a high-performance, infinite procedural voxel world. This manual is a comprehensive, step-by-step documentation designed to help you navigate, mine, build, fight, trade, sort your backpack, and craft advanced tools.

---

## 1. Getting Started: The Main Menu
When you launch CraftDomain, you enter a polished, glassmorphic **Main Menu** set against a scenic, rotating procedurally generated backdrop, accompanied by a dynamic looping acoustic soundtrack.
* **PLAY WORLD:** Instantly initiates or restores your infinite world. If a save file is detected, you will be loaded precisely at your last coordinates, with your edits, modifications, and exact inventory quantities intact.
* **SETTINGS:** Opens the settings overlay to dynamically control Music Volume, Sound Effects Volume, and adjust display resolutions (Windowed vs Fullscreen).
* **EXIT GAME:** Closes the game application window safely.

---

## 2. Character Mechanics, Spawning & Navigation

As you join the world, the engine runs a vertical spawn scan at your coordinates, finding the top-most solid block (up to height 31) and dropping you smoothly onto the surface.

### The GPS HUD & 2D Circular Radar Minimap
Located in the upper right-hand corner of your screen is a high-contrast **GPS Navigation Overlay** designed to keep you oriented:
* **The Selected Arrow (Center):** Represents your character on the circular radar. It rotates dynamically in real-time with a thick black outline as you turn your camera.
* **Real-time Grid Coordinates:** Located at the top center of the HUD, showing your exact global `[ X  ·  Y  ·  Z ]` block coordinates alongside the synchronized 24-hour clock.
* **Active Mission Tracker:** Renders active quest descriptions, remaining distance in meters, and progress bars. The panel automatically hides itself from the screen when all campaign quests are completed.
* **Active Quest Marker:** Indicated by a pulsing hot-pink diamond on the minimap. When you are far from the target, the diamond clamps cleanly to the outer compass rim, guiding your gaze toward the destination.
* **Radar Colors Mapping:**
  * **Vibrant Tropical Blue:** Bay of Sails (Spawn Ocean).
  * **Emerald Green:** Warp Plateau (Mario Steps).
  * **Warm Golden Yellow:** Golden Bazaar (Trading Plains).
  * **Dark Grey:** Craggy Peaks & Caves.
  * **Pristine White:** Frostbite Glaciers (Polar Cap).
  * **Deep Forest Green:** Whispering Redwood Forest.
  * **Terracotta Orange:** Red Sandstone Canyons.
  * **Electric Cyan:** Neon Ruins (Cyber Basin).
  * **Muddy Dark Brown:** Swamp of Sighs.

---

## 3. Keyboard & Mouse Controls Reference

The input mapping system is processed in raw hardware buffers inside `_unhandled_input` to avoid high-frequency jitter. It supports both WASD and standard keyboard Arrow Keys:

| Action | Primary Key | Secondary Key | Mouse Action | Description |
| :--- | :---: | :---: | :---: | :--- |
| **Move Forward** | `W` | `Up Arrow` | - | Walk forward |
| **Move Backward**| `S` | `Down Arrow` | - | Walk backward |
| **Move Left**    | `A` | `Left Arrow` | - | Strafe left |
| **Move Right**   | `D` | `Right Arrow` | - | Strafe right |
| **Jump**         | `Space` | - | - | Jump over blocks |
| **Pause & Save** | `Escape` | - | - | Unlocks mouse cursor & auto-saves |
| **Mining/Attack**| `E` | - | `Left-Click` | Swing active tool, break block, hit |
| **Build/Interact**| `Q` | - | `Right-Click` | Place block, eat chicken, trade, open chest |
| **Scroll Hotbar** | - | - | `Mouse Wheel` | Scroll left/right through slots |
| **Open Inventory**| `I` | - | - | Toggle Backpack Grid & Item Inspector |
| **Open Crafting** | `C` | - | - | Toggle Blueprint Catalog & Crafting Workshop |
| **Select Slot 1** | `1` | - | - | Select Stone Block |
| **Select Slot 2** | `2` | - | - | Select Dirt Block |
| **Select Slot 3** | `3` | - | - | Select Grass Block |
| **Select Slot 4** | `4` | - | - | Select Wood Trunk Block |
| **Select Slot 5** | `5` | - | - | Select Shrubbery Leaves Block |
| **Select Slot 6** | `6` | - | - | Select Lava Bucket (Placable Liquid) |
| **Select Slot 7** | `7` | - | - | Select Fried Chicken (Healing Food) |
| **Select Slot 8** | `8` | - | - | Select Wooden Sword (Weapons) |

---

## 4. Mining, Building & Handheld Tools

Interacting with voxels is governed by a **5-meter Reach Distance**. A white aiming reticle sits at the center of the screen, and a **3D glowing target highlighter box** outlines the exact block your cursor is targeting.

```
	   [Aiming Reticle]  --->  [ + ] 
								 |
								 v
	   [Target Highlighter] -> [ ▱ ] (Snaps to 3D Voxel Grid)
```

### Mining (Breaking Blocks)
1. Aim at any block within range.
2. Press **Left-Click** (or `E`).
3. The block breaks, triggering a **dynamic particle debris emitter** that sprays color-matched 3D voxel particles for visceral impact. The block is then added to your inventory.
4. **Visual Hotbar Feedback:** Each slot has an elegant, color-coded central icon block representing the material with a 3D-shaded inner relief overlay, with active item counts displayed in the bottom-right corner. When you select a slot, the full item name (e.g., `WOOD LOG`) appears floating above the hotbar and fades out smoothly after 1.8 seconds.

### Building (Placing Blocks & Lava)
1. Select a material using the **Mouse Wheel** or keys **1 to 6**.
2. Aim at any solid block surface. The white highlighter box will outline the target.
3. Press **Right-Click** (or `Q`).
4. The block is placed adjacent to the face you were pointing at.
5. **Lava Placement:** Selecting your **Lava Bucket** (Slot 6) and Right-Clicking will place a glowing, flowing orange **Lava block** in the world, consuming 1 Lava Bucket from your hotbar.

---

## 5. Procedural Voxel Biomes & Weather Atmosphere

The world features 10 completely distinct geographical regions, each populated with unique resources, trees, and buildings:

```
				  [ North Cap: Polar Glaciers ]
							   ^
							   |
  [ Swamp of Sighs ] <--- [Spawn Bay] ---> [ Golden Bazaar ]
							   |
							   v
				  [ South Cap: Warp Plateau ]
```

### The 10 Geographical Regions

#### 1. Bay of Sails (Spawn Ocean - Center)
* **Description:** A tropical, sandy shoreline surrounding a vast blue water bay.
* **Flora/Landmarks:** Rustic wooden piers and harbor docks.

#### 2. Warp Plateau (Mario Steps - South)
* **Description:** A vibrant green grassland characterized by giant vertical step-like plateaus.
* **Flora/Landmarks:** Spawns giant, red-spotted Mario mushrooms and green hollow Warp Pipes.

#### 3. Golden Bazaar (Village Plains - East)
* **Description:** Flat, smooth sunlit fields perfect for establishing trading settlements.
* **Flora/Landmarks:** High concentration of rustic wooden cabins and active merchant stalls.

#### 4. Craggy Peaks & Caves (North Mountains)
* **Description:** Jagged, tall stone mountain ranges that overlook dark caves below.
* **Flora/Landmarks:** Spawns wooden mine pillars topped with glowing lanterns.

#### 5. Frostbite Glaciers (Polar Cap - Far North)
* **Description:** A freezing, quiet basin of solid ice and deep snowdrifts.
* **Flora/Landmarks:** Spawns majestic, hollow spires built entirely of frozen blue ice.

#### 6. Whispering Redwood Forest (North West)
* **Description:** Densely forested, mossy green valleys carpeted in rich grass.
* **Flora/Landmarks:** Covered in towering, multi-tiered coniferous Giant Redwood trees.

#### 7. Red Sandstone Canyons (Far South)
* **Description:** Terraced, deep desert canyons sculpted into steps of reddish terracotta sandstone.
* **Flora/Landmarks:** Rocky canyons with sharp drops.

#### 8. Neon Ruins (Cyber Basin - Far West)
* **Description:** A dark, technological crater lined with active cybernetic pathways.
* **Flora/Landmarks:** Spawns ancient stepped pyramids radiating glowing cyan and magenta light blocks.

#### 9. Swamp of Sighs (Mist Bay - North West)
* **Description:** Depressed, murky valleys filled with dark, sticky mud and stagnant water.
* **Flora/Landmarks:** Covered in dense foliage.

#### 10. Cloud Kingdom (Floating Isles - Sky)
* **Description:** Beautiful, floating islands made of fluffy white cloud voxels drifting high in the atmosphere.
* **Flora/Landmarks:** Spawns above height Y=12.

### Dynamic GPU Overcast System
The sky is rendered with an advanced GPU shader that reacts dynamically to weather shifts:
* **Sunny Weather:** Fluffy, procedurally generated white clouds float across a bright blue sky, with a crisp glowing sun disk orbiting above.
* **Overcast & Precipitation:** When rain or snow begins, the sky color shifts progressively to a plomizo slate-grey over 5 seconds. The clouds turn dark and dense, and the Sun and Moon disks dim by 85%, creating an immersive storm atmosphere.
* **Night Cycle:** The clouds turn a deep navy blue, allowing twinkling stars and a glowing, silver crescent moon to shine through.

---

## 6. Passive Fauna, Active AI & The Trading Economy

The procedural world is populated with active, box-composition creatures and villagers who display organic, real-time behaviors.

```
	   [Idle State] ---> [Wander State] ---> [Examine State] (Farming)
							   |
					 (Player enters radius)
							   v
						[Greeting State] (Stops & Nods Head)
```

### Dynamic Eye Blinking & Step-Bouncing Walk Cycles
* All mobs feature detailed 3D eyes. Every 3 to 6 seconds, they procedurally **blink** by flattening their eyes vertically for a fraction of a second.
* When moving, they display smooth walk cycles using a **`_body_bob_node` step-bouncing system** that makes their entire body bounce with weight, coupled with realistic head sways and idle breathing.

### Specialized Community Roles
* **Villagers:** Clothed in textured brown robes with leather boots and sashes.
* **Merchants:** Styled with purple robes, silk turbans with embedded emerald gems, and dual-layered gold aprons.
* **Guards:** Overhauled with metallic pauldrons, iron greaves, combat visor helmets, and sheathed iron swords and knightly shields on their backs.
* **Farmers:** Rigged with muddy field boots, denim dungarees with suspenders, wide-brim straw hats, and sheathed wood-iron hoes.

### Interactive 3D Loot Chests
Inside village settlements, you will discover interactive **3D Loot Chests** spawned near buildings.
1. Approach a chest and press **Right-Click** (or `Q`).
2. The chest will play a physical scaling pop animation, award you a random reward (such as a *Fried Chicken* or a *Lava Bucket*), trigger a sliding **"Loot Found!"** notification toast, and delete itself safely.

### The Lava-Fried Chicken Trade Loop
Inside villages (found in the **Golden Bazaar** plains), you will discover rustic market cabins with an active Merchant standing nearby.

```
 [ Player ] --- Gives: 1x Lava Bucket (Key 6) ---> [ Merchant ]
	|                                                    |
 [ Player ] <--- Receives: 1x Fried Chicken <----------- [ Merchant ] (Hops in the air!)
```

1. Hold your **Lava Buckets** (Select Slot 6).
2. Aim at the Merchant and **Right-Click** (or `Q`).
3. The Merchant will hum excitedly, **hop in the air with physical joy**, consume 1 Lava Bucket, and place 1 **Fried Chicken** into your inventory.
4. If you attempt to interact without holding a Lava Bucket, the Merchant will hum inquisitively, and the developer console will print: `[Merchant] Hmmm? Bring me a Bucket of Lava (Slot 6) to trade for my Lava-Fried Chicken!`

---

## 7. Combat & Hostile Entities

As night falls (the sun rotates below the horizon, monitored by the dynamic day/night service), dangerous hostiles can emerge.

```
 [ Player HP: ❤ ❤ ❤ ] <--- Damage (Zombies) ---> [ Screens Flashes Red ]
   ^
   |  (Eat Fried Chicken)
 [ Consume Chicken ]
```

### The Zombie Threat
* **Behaviors:** Zombies wander searching for flesh. If you enter their aggro range, they will chase you down, climb blocks automatically, and bite you.
* **Damage Feedback:** Getting bitten deals **1 Heart** of damage, pushes you backward with physical recoil, flashes your screen with a deep red vignette, and triggers a high-frequency decaying camera trauma shake.
* **Death & Respawn:** If you lose all 3 hearts, you will die, resetting your health back to full, and respawning safely on top of your designated spawn area.

### Combat with the Wooden Sword
1. Press **Key 8** to hold your **Wooden Sword** (Slot 8). The sword has infinite durability.
2. Aim at a zombie and **Left-Click** (or `E`) to swing.
3. Successfully hitting a zombie deals 1 damage, triggers a satisfying **red damage flash** on their body, and applies a **diagonal knockback impulse**, throwing them backward and slightly upward. Zombies take 3 hits to defeat.

---

## 8. The Automated Delta-Save Pipeline

CraftDomain features a silent, zero-stutter background **Delta-Save** process. You never have to manually click a save button:

1. Pressing **Escape** pauses the game and unlocks your mouse cursor.
2. The engine instantly gathers your current `(X, Y, Z)` position, camera look angles, world seed, and full 24-slot backpack item and stack quantities, writing them to `user://world_save/global_save.json`.
3. Simultaneously, any blocks you broken or placed are gathered as localized modification deltas and saved directly to chunk files on disk (e.g., `chunk_-21_1_10.json`).
4. When you click **PLAY WORLD** on the Main Menu, the loading queue restores the world, rendering your construction edits and loading your character precisely where you paused!

---

## 9. Backpack Inventory & Item Inspector (`I`)

Pressing **`I`** (or clicking the **`🎒`** HUD shortcut button) freezes the gameplay physics and opens a detailed **Backpack Inventory & Inspector** overlay.

```
+------------------------------------+--------------------------+
|          BACKPACK GRID             |      ITEM INSPECTOR      |
|                                    |                          |
|  [ 8 ]  [ 9 ]  [10]  [11]          |      [ WOOD LOG ]        |
|  [12]  [13]  [14]  [15]          |                          |
|  [16]  [17]  [18]  [19]          |          [ 📦 ]          |
|  [20]  [21]  [22]  [23]          |        (3D Preview)      |
|                                    |                          |
|  HOTBAR DOCK (Separated)           | "Sturdy oak logs... used |
|  [ 0 ] [ 1 ] [ 2 ] [ 3 ] ... [ 7 ] |  for dynamic builds."    |
|                                    |                          |
|                                    |  STOCKED: 16 units       |
|                                    |                          |
|                                    | [ EQUIP ]  [ USE/EAT ]   |
+------------------------------------+--------------------------+
```

### Stack-Based 24-Slot Storage Grid
* **Hotbar Dock (Slots 0 to 7):** The 8 quickbar slots centered at the bottom of the HUD. Items in these slots can be held in your hands to build, mine, or fight.
* **Backpack Grid (Slots 8 to 23):** The upper 16 storage slots of your backpack, designed to hold auxiliary resources, crafted items, and mined blocks.
* **Apilamiento (Max Stack 64):** Items stack dynamically up to 64 units per slot (excluding weapons which occupy single non-stackable slots). You can hold multiple separate stacks of the same material across the grid.

### The Sequential Swapping Engine (Inventory Sorting)
You can reorganize your inventory or move items between your backpack and your hotbar with a simple, tactile clicking sequence:
1. Click on **Slot A** (the slot will glow in a prominent Gold frame indicating active selection).
2. Click on any **Slot B**.
3. The contents of both slots will physically **swap positions** instantly on your screen, updating your active hands and quickbar in real-time! Click Slot A again to deselect.

### The Item Inspector (Utility Tooltips & Fast Use)
Clicking any item in the backpack displays its specific gameplay profiles:
* **Description Tooltip:** Teaches the player the utility and lore of each block or tool.
* **Operational Instructions:** Spells out exact controller shortcuts (e.g., *"Use Right-Click to place blocks"*).
* **Equip Action:** Click **EQUIP IN HAND** to assign the selected item to that quickbar slot instantly.
* **Fast Use (Eating Food):** If you inspect Fried Chicken, a green **CONSUME FOOD** button appears. Clicking it eats 1x chicken directly from your bag, healing 1 Heart on your HUD.

---

## 10. Blueprint Taller & Crafting Workshop (`C`)

Pressing **`C`** (or clicking the **`🛠️`** HUD shortcut button) opens a dual-pane **Blueprint Taller & Crafting Workshop** overlay, allowing you to manufacture advanced equipment and process terrain materials.

```
+------------------------------------+--------------------------+
|          BLUEPRINT CATALOG         |      FORMULA DETAILS     |
|                                    |                          |
|  🧱 Grass Turf Blocks              |       SOD CULTIVATION    |
|  🧱 Reinforced Stone Slabs         |                          |
|  🛠️ Wooden broadswords             |          [ 🧱 ]          |
|  🍗 Emergency Herbal Rations       |        (Output Preview)  |
|                                    |                          |
|                                    |  REQUIRED MATERIALS:     |
|                                    |  ✔ 2 / 2  DIRT BLOCK     |
|                                    |  ✘ 0 / 1  LEAVES         |
|                                    |                          |
|                                    |     [ FABRICATE ITEM ]   |
+------------------------------------+--------------------------+
```

### The Recipe Catalog (Left Pane)
Displays a scrollable deck of all available crafting blueprints. Each card features a color-coded vertical strip matching the material of the result for immediate visual category identification.

### The Formula Details & Checklist (Right Pane)
Selecting a blueprint shows its visual specifications:
* **Inputs Checklist:** Scans your **entire 24-slot inventory** dynamically to aggregate your current stock of each required item, showing a green checkmark (`✔`) if you have enough, or a red cross (`✘`) if you are missing materials.
* **Fabricate Action:** If the requirements are met, the **FABRICATE ITEM** button unlocks in green. Clicking it consumes the materials globally across your backpack, grants the crafted outcome, triggers a viewmodel hand-swing, and pops a sliding success notification.

### Full Recipe List Reference (12 formulas):
*   **Organic Composting:** `3x Leaves` ➔ `1x Dirt`
*   **Sod Cultivation:** `2x Dirt` + `1x Leaves` ➔ `2x Grass`
*   **Thatch Harvesting:** `1x Wood` ➔ `4x Leaves`
*   **Soil Pulverizer:** `1x Stone` ➔ `3x Dirt`
*   **Igneous Cobbling:** `4x Dirt` + `1x Lava` ➔ `4x Stone`
*   **Wooden Sword:** `4x Wood` ➔ `1x Wooden Sword`
*   **Emergency Herbal Rations:** `10x Leaves` + `1x Wood` ➔ `1x Fried Chicken`
*   **Geothermal Charcoal Fuel:** `6x Wood` + `1x Lava` ➔ `3x Lava Buckets`
*   **Reinforced Stone Slabs:** `2x Stone` + `1x Dirt` ➔ `3x Stone`
*   **Composite Planks:** `2x Wood` + `1x Stone` ➔ `4x Wood`
*   **Magma Core Synthesis:** `15x Stone` + `1x Lava` ➔ `2x Lava Buckets`
*   **Soothing Herbal Poultice:** `6x Leaves` ➔ `1x Fried Chicken`
