# CraftDomain - Ultimate Gameplay & Survival Manual
*Written by Enrique González Gutiérrez (enrique.gonzalez.gutierrez@gmail.com)*

Welcome to **CraftDomain**, a high-performance, infinite procedural voxel world. This manual is a comprehensive, step-by-step documentation designed to help you navigate, mine, build, fight, and trade. 

---

## 1. Getting Started: The Main Menu
When you launch CraftDomain, you enter a polished, glassmorphic **Main Menu** set against a scenic, rotating procedurally generated backdrop, accompanied by a dynamic looping acoustic soundtrack.
* **PLAY WORLD:** Instantly initiates or restores your infinite world. If a save file is detected, you will be loaded precisely at your last coordinates, with your edits, modifications, and exact inventory quantities intact.
* **EXIT GAME:** Closes the game application window safely.

---

## 2. Character Mechanics, Spawning & Navigation

As you join the world, the engine runs a vertical spawn scan at your coordinates, finding the top-most solid block (up to height 31) and dropping you smoothly onto the surface.

### The GPS HUD & 2D Circular Radar Minimap
Located in the upper right-hand corner of your screen is a high-fidelity **GPS Navigation Overlay** designed to keep you oriented:
* **The Yellow Arrow (Center):** Represents your character. It rotates dynamically in real-time as you turn your camera.
* **Real-time Grid Coordinates:** Located at the top center of the HUD, showing your exact global `[ X  ·  Y  ·  Z ]` block coordinates.
* **Regional Compass Card:** Displays your current biome location (e.g., `REGION: GOLDEN BAZAAR`) and dynamically calculates your distance to major geographical landmarks (e.g., `[N] Polar Ice: 450m | [E] Village Bazaar: 300m`).
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
  * **Pure Fluffy White:** Cloud Kingdom (Floating Isles).

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
| **Build/Interact**| `Q` | - | `Right-Click` | Place block, eat chicken, trade |
| **Scroll Hotbar** | - | - | `Mouse Wheel` | Scroll left/right through slots |
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
3. The block breaks instantly and is added to your inventory. The viewmodel plays a rapid swinging animation, and the HUD updates your item counters.

### Building (Placing Blocks & Lava)
1. Select a material using the **Mouse Wheel** or keys **1 to 6**.
2. Aim at any solid block surface. The white highlighter box will outline the target.
3. Press **Right-Click** (or `Q`).
4. The block is placed adjacent to the face you were pointing at.
5. **NEW FEATURE: Lava Placement!** Selecting your **Lava Bucket** (Slot 6) and Right-Clicking will place a glowing, flowing orange **Lava block** in the world, consuming 1 Lava Bucket from your hotbar.

---

## 5. Procedural Voxel Biomes & Structures

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

### 1. Bay of Sails (Spawn Ocean - Center)
* **Description:** A tropical, sandy shoreline surrounding a vast blue water bay.
* **Flora/Landmarks:** Rustic wooden piers and harbor docks.

### 2. Warp Plateau (Mario Steps - South)
* **Description:** A vibrant green grassland characterized by giant vertical step-like plateaus.
* **Flora/Landmarks:** Spawns giant, red-spotted Mario mushrooms and green hollow Warp Pipes.

### 3. Golden Bazaar (Village Plains - East)
* **Description:** Flat, smooth sunlit fields perfect for establishing trading settlements.
* **Flora/Landmarks:** High concentration of rustic wooden cabins and active merchant stalls.

### 4. Craggy Peaks & Caves (North Mountains)
* **Description:** Jagged, tall stone mountain ranges that overlook dark caves below.
* **Flora/Landmarks:** Spawns wooden mine pillars topped with glowing lanterns.

### 5. Frostbite Glaciers (Polar Cap - Far North)
* **Description:** A freezing, quiet basin of solid ice and deep snowdrifts.
* **Flora/Landmarks:** Spawns majestic, hollow spires built entirely of frozen blue ice.

### 6. Whispering Redwood Forest (North West)
* **Description:** Densely forested, mossy green valleys carpeted in rich grass.
* **Flora/Landmarks:** Covered in towering, multi-tiered coniferous Giant Redwood trees.

### 7. Red Sandstone Canyons (Far South)
* **Description:** Terraced, deep desert canyons sculpted into steps of reddish terracotta sandstone.
* **Flora/Landmarks:** Rocky canyons with sharp drops.

### 8. Neon Ruins (Cyber Basin - Far West)
* **Description:** A dark, technological crater lined with active cybernetic pathways.
* **Flora/Landmarks:** Spawns ancient stepped pyramids radiating glowing cyan and magenta light blocks.

### 9. Swamp of Sighs (Mist Bay - North West)
* **Description:** Depressed, murky valleys filled with dark, sticky mud and stagnant water.
* **Flora/Landmarks:** Covered in dense foliage.

### 10. Cloud Kingdom (Floating Isles - Sky)
* **Description:** Beautiful, floating islands made of semi-transparent, fluffy white cloud voxels drifting high in the atmosphere.
* **Flora/Landmarks:** Spawns above height Y=12.

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

### Dynamic Eye Blinking & Head Bobbing
* All mobs feature detailed 3D eyes. Every 3 to 6 seconds, they procedurally **blink** by flattening their eyes vertically for a fraction of a second.
* When moving, they display smooth walk cycles, swaying their heads, wings, or arms to eliminate stiff robotic motions.

### NPC Tasks & Social Behaviors
* **Examine (Farming/Inspecting):** Villagers and Merchants will periodically stop, look downward at a block, and sway their arms up and down, simulating hoeing, digging, or inspecting.
* **Greeting (Player Interaction):** If you walk within 3.5 meters of a Villager or Merchant, they will stop what they are doing, rotate their bodies to face you, and **nod their heads up and down** to greet you.

### The Lava-Fried Chicken Trade Loop
Inside villages (found in the **Golden Bazaar** plains), you will discover rustic market cabins with a **Purple-Robed Merchant Villager** wearing a golden apron standing nearby.

```
 [ Player ] --- Gives: 1x Lava Bucket (Key 6) ---> [ Merchant ]
	|                                                    |
 [ Player ] <--- Receives: 1x Fried Chicken <----------- [ Merchant ] (Hops in the air!)
```

1. Hold your **Lava Buckets** (Select Slot 6). The HUD will display: `[ LAVA BUCKET ]` and show your remaining count.
2. Aim at the Merchant and **Right-Click** (or `Q`).
3. The Merchant will hum excitedly, **hop in the air with physical joy**, consume 1 Lava Bucket, and place 1 **Fried Chicken** into your inventory.
4. If you attempt to interact without holding a Lava Bucket, the Merchant will hum inquisitively, and the developer console will print: `[Merchant] Hmmm? Bring me a Bucket of Lava (Slot 6) to trade for my Lava-Fried Chicken!`

### Survival & Healing
When selecting your **Fried Chickens** (Slot 7), if you have taken damage, **Right-Click** (or `Q`) to eat. You will consume 1 chicken, play a satisfying hand-tilt animation, and heal **1 Heart (❤)** of health.

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
* **Damage Feedback:** Getting bitten deals **1 Heart** of damage, pushes you backward with physical recoil, and **flashes your screen with a deep red vignette** for immediate combat feedback.
* **Death & Respawn:** If you lose all 3 hearts, you will die, resetting your health back to full, and respawning safely on top of your designated spawn area.

### Combat with the Wooden Sword
1. Press **Key 8** to hold your **Wooden Sword** (Slot 8). The sword has infinite durability.
2. Aim at a zombie and **Left-Click** (or `E`) to swing.
3. Successfully hitting a zombie deals 1 damage, triggers a satisfying **red damage flash** on their body, and applies a **diagonal knockback impulse**, throwing them backward and slightly upward. Zombies take 3 hits to defeat.

---

## 8. The Automated Delta-Save Pipeline

CraftDomain features a silent, zero-stutter background **Delta-Save** process. You never have to manually click a save button:

1. Pressing **Escape** pauses the game and unlocks your mouse cursor.
2. The engine instantly gathers your current `(X, Y, Z)` position, camera look angles, world seed, and hotbar inventory quantities, writing them to `user://world_save/global_save.json`.
3. Simultaneously, any blocks you broken or placed are gathered as localized modification deltas and saved directly to chunk files on disk (e.g., `chunk_-21_1_10.json`).
4. When you click **PLAY WORLD** on the Main Menu, the loading queue restores the world, rendering your construction edits and loading your character precisely where you paused!
