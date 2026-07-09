# CraftDomain - Gameplay & Survival Manual
*Written by Enrique González Gutiérrez (enrique.gonzalez.gutierrez@gmail.com)*

Welcome to **CraftDomain**, a high-performance, commercial-grade infinite procedural voxel engine. This manual is a comprehensive, step-by-step documentation designed to help you navigate, mine, build, fight, trade, sort your backpack, and craft advanced tools.

---

## 1. Getting Started: The Main Menu & Settings
When you launch CraftDomain, you enter a polished, **Tactile Glassmorphic Main Menu** set against a scenic, rotating procedurally generated backdrop.
*   **PLAY WORLD / NEW GAME:** Instantly initiates or restores your infinite world. If a save file is detected, you will be loaded precisely at your last coordinates, with your edits, modifications, and exact inventory quantities intact.
*   **SETTINGS:** Opens the responsive settings overlay to dynamically control Music Volume, Sound Effects (SFX) Volume, Render Distance (up to 14 chunks), Interface Languages (English vs Español), and Display Resolutions.
*   **EXIT GAME:** Closes the game application window safely.

*Note: All menus feature physical 3D button styling that depresses visually on click, complete with hover scaling and smooth transition animations.*

---

## 2. Character Mechanics, Navigation & UI

As you join the world, the engine runs a vertical spawn scan at your coordinates, finding the top-most solid block (up to height 31) and dropping you smoothly onto the surface.

### Quadrupled Horizon View Distance (162-Chunk Radius)
Through massive occlusion culling and opaque Far-LOD material bypassing, the engine pushes a **9x2x9 3D loading grid**. This active volume of **162 procedural chunks** quadruples the standard visual draw distance natively, allowing you to see mountain peaks and castles way in the distance while maintaining a locked 120 FPS.

### The GPS HUD & 2D Circular Radar Minimap
Located in the upper right-hand corner of your screen is a high-contrast **GPS Navigation Overlay** designed to keep you oriented. To save CPU cycles, these metrics are intelligently throttled to refresh 20 times per second.
*   **The Selected Arrow (Center):** Represents your character on the circular radar. It rotates dynamically in real-time.
*   **Real-time Grid Coordinates:** Located at the top center of the HUD, showing your exact global `[ X  ·  Y  ·  Z ]` block coordinates alongside the synchronized 24-hour clock.
*   **Active Mission Tracker:** Renders active quest descriptions, remaining distance in meters, and inventory progress bars. For gathering quests, it dynamically routes you to the nearest natural resource hotspot (e.g., pointing to Nether Outposts for Lava).
*   **Holographic GPS Path Line:** The minimap renders a dynamic, pulsing, dashed pink path-line connecting your character's center position directly to the active quest target.
*   **Tactical Compass Pointer:** The GPS HUD dynamically identifies the closest Global Mega-Structure, displaying its name, distance, and cardinal direction (N, NE, E, SE, S, SW, W, NW).
*   **3D Altitude-Aware Radar:** Displays dynamic height indicators. For tracked targets, the minimap renders specialized vertical chevrons (`^` or `v`) indicating whether the target lies far above (on a cliff/air) or deep below (inside a cave/mine shaft), providing full tridimensional navigation.

---

## 3. Keyboard & Mouse Controls Reference

The input mapping system is processed in raw hardware buffers to avoid high-frequency jitter. 

| Action | Primary Key | Secondary Key | Mouse Action | Description |
| :--- | :---: | :---: | :---: | :--- |
| **Move Forward** | `W` | `Up Arrow` | - | Walk forward |
| **Move Backward**| `S` | `Down Arrow` | - | Walk backward |
| **Move Left**    | `A` | `Left Arrow` | - | Strafe left |
| **Move Right**   | `D` | `Right Arrow` | - | Strafe right |
| **Jump**         | `Space` | - | - | Jump over blocks |
| **Pause & Save** | `Escape` | - | - | Opens the Pause Menu & Auto-saves |
| **Mining/Attack**| `E` | - | `Left-Click` | Swing active tool, break block, hit |
| **Build/Interact**| `Q` | - | `Right-Click` | Place block, eat chicken, trade, open chest |
| **Scroll Hotbar** | - | - | `Mouse Wheel` | Scroll left/right through slots |
| **Open Inventory**| `I` | - | - | Toggle Backpack Grid & Item Inspector |
| **Open Crafting** | `C` | - | - | Toggle Blueprint Catalog & Crafting Workshop |
| **Open World Map**| `M` | - | - | Toggle Fullscreen Tactical Map Overlay |
| **Free Cursor**   | `Left Alt` | - | - | Hold to release captured mouse cursor |

---

## 4. Mining, Building & Audio Soundscapes

Interacting with voxels is governed by a **5-meter Reach Distance**. The engine features an immersive **Observer-Driven Audio System**: every footstep, block break, and placement triggers terrain-specific 3D positional audio (Grass, Stone, Wood, Snow).

### Holographic Placement Preview & Safety Shields
When holding a buildable block, a 3D preview box outlines your target:
*   **Emerald Green:** The spot is valid and empty.
*   **Ruby Red:** The spot is blocked by your own body. The engine mathematically pads your collision by 5cm, preventing you from trapping your character inside solid blocks.

### Advanced Building (Slabs & Liquids)
1.  **Standard Blocks:** Select a material, aim at an adjacent face, and Right-Click.
2.  **Half-Slabs (ID 26):** CraftDomain features advanced fractional raycasting. 
    * Aiming at the *top half* of a block face places a Top Slab.
    * Aiming at the *bottom half* places a Bottom Slab.
    * **Merging:** Right-clicking directly on the top face of a Bottom Slab (or bottom face of a Top Slab) will magically fuse them into a single, solid full Stone block!
3.  **Lava Placement:** Right-Clicking with a **Lava Bucket** (ID 15) places glowing, flowing orange Lava in the world, consuming 1 Bucket.
4.  **Crop Planting:** Right-Clicking with **Crop Seeds** (ID 18) on top of Grass or Dirt will sow a young sprout that grows over time.
5.  **Sub-pixel Hermetic Sealing:** Transparent liquid and slab vertices are mathematically scaled outward from their block center by a factor of `1.002` (2 millimeters), tightly overlapping chunk borders to permanently eliminate all Z-fighting and sub-pixel light leaks.
6.  **Compile-Free Unshaded Particles:** Spawns unshaded `CPUParticles3D` on block breaking, bypassing runtime GPU shader compilations completely and maintaining a solid 120 FPS.
7.  **Unified Surface Normals Baking:** Slabs and transparent fluids are compiled inside `ChunkMesher` with dynamic normal generation (`generate_normals()`), securing realistic specular lighting highlights and allowing water/lava waves to sway along the custom wind direction correctly.

---

## 5. Procedural Voxel Biomes & Weather Atmosphere

The world features 10 completely distinct geographical regions, each implementing its own **Polymorphic Boundary Strategy** (`is_coordinate_inside()`) to dynamically determine their territorial limits:

*   **Bay of Sails:** Tropical shores with aquatic Sea Turtles.
*   **Warp Plateau:** Vibrant green step-plateaus with giant Mario mushrooms.
*   **Golden Bazaar:** Trading plains with Oak, Sakura, and Birch trees.
*   **Craggy Peaks & Caves:** Jagged stone mountains and dark caverns.
*   **Frostbite Glaciers:** Freezing, quiet basin of solid ice and deep snowdrifts.
*   **Whispering Redwood Forest:** Mossy green valleys with towering 12-block Redwoods.
*   **Red Sandstone Canyons:** Terraced badlands with twisted Dead Shrubs.
*   **Neon Ruins:** Dark technological craters with glowing cyan/magenta pyramids.
*   **Swamp of Sighs:** Depressed, murky valleys filled with dark mud.
*   **Cloud Kingdom:** High-altitude floating white cloud islands.

### Atmospheric Shading & Weather
*   **Soft Ambient Fill:** Shadows are filled with a realistic atmospheric blue-gray ambient light, making blocks and NPCs inside tree shadows completely readable.
*   **Dynamic GPU Overcast System:** When rain or snow begins, the sky smoothly fades to a heavy slate-grey. Clouds thicken and dim the Sun/Moon by 85%.
*   **Global Wind Engine:** Water waves and tree leaves deform and sway physically, reacting in real-time to the global wind direction and storm strength.

---

## 6. Passive Fauna, Active AI & The Trading Economy

The procedural world is populated with active creatures and villagers featuring detailed pixel-grain textures, blinking eyes, and physical body-bobbing walk cycles.

### High-Performance AI Throttling
To keep the game running at a flawless 120 FPS, AI tactical scans are heavily optimized. They utilize Godot's $O(1)$ group registries and are throttled to run exactly **4 times per second**, reducing CPU load by 95% without losing responsiveness.
*   **Dynamic AI Tick Throttle (LOD AI):** Mobs right next to the player (<15m) update at 20Hz, while distant mobs scale down their logical updates to 4Hz or 0.5Hz, saving massive CPU cycles.

### Intelligent 3D Pathfinding & Schedulers
*   **A* Voxel Pathfinding:** NPCs navigate using a 3D coordinate graph. They calculate paths around obstacles, climb stairs/slabs, and walk along village layouts.
*   **Day/Night & Storm Shelter Schedules:** At sunset or during storms, civilian NPCs (Villagers, Merchants, Farmers, Miners, Druids) cancel their tasks, locate the closest registered indoor shelter (roofed coordinates), and plan an A* path to run inside safely.
*   **Intelligent Land/Water Boundary checks:** Land-dwelling civilians strictly avoid falling into deep voids (AIR) or walking into liquid Water/Lava, while aquatic species (Turtles) remain constrained to water and sand shores. Bumping against walls instantly triggers course-corrections.

### 17+ Specialized Decoupled AI Strategies
Instead of raw, bulky physics scripts, every entity delegates its decisions to isolated strategy classes in the Domain:
*   **Gossip Villagers:** Seek nearby peers to stand in gossip circles, chatting and gesticulating while emitting cyan dialogue bubbles.
*   **Barkeep Merchants:** Tend shopfront stalls by day and retreat to safe village taverns to count their golden coins by night (spawning shiny golden sparks).
*   **Agricultural Farmers:** Search for mature wheat, walk over, draw a visual hoe to harvest and replant seeds with green particle feedback.
*   **Industrial Cave Miners:** Scan adjacent coordinates for deep Coal Veins, walk over, draw a visual pickaxe to mine, and replace the coal globally with raw Stone while triggering rocky break particles.
*   **Forest Sages (Druids):** Patrol redwood glades, meditate near shrines, and channel visual streams of unshaded emerald éter particles to completely heal injured nearby animals.
*   **Cyber Citizens (Androids):** Align to paved highway roads, walking in strict angles and halting to execute 360-degree security sweeps emitting cyan laser beams.
*   **Sea Turtles & Beach Crabs:** Unified amphibious strategies. Swim with fluid sinusoid buoyancy sways in deep water and crawl slowly with heavy speed penalties on sandy beach shores.
*   **Deep-Water Octopuses:** Swim using timed jet propulsion bursts followed by drift gliding, and trigger an emergency siphon spraying a thick black ink cloud when damaged.
*   **Forest Fox Predators:** Sneak and crawl flatly along the grass to avoid drawing alert, and launch themselves in majestic high-parabola pounce jumps to hunt chickens and birds.
*   **Colossal Elephants:** March in slow, ponderous stride cycles. Completing a stride triggers a heavy stone thud and a camera shake rumble for nearby players. Immune to push knockbacks due to mass.
*   **Avian Yellow Birds & Parrots:** Flight height compensated avians. Soar high in wide 3D thermal gliding soar rings, and descend to perch flatly on top of tree canopies.

### Interactive 3D Loot Chests & Trading
1.  **Loot Chests:** Right-click a 3D chest in a village. It will pop, play a `chest_open` sound effect, grant you a reward, and vanish safely.
2.  **Lava-Fried Chicken Trade:** Hold a **Lava Bucket** and Right-Click a Merchant. They will hop with joy, consume the lava, and give you 1x **Fried Chicken**.
3.  **Voxel-Support Block Gravity:** Breaking blocks underneath props cause them to fall: destructible props (barrels, chests, campfires) shatter and drop loot, while heavy structural props (wishing wells, streetlights) slide down to the new floor level with elastic bouncing Tweens.

---

## 7. Combat, Defenders & Hostile Entities

As night falls, dangerous hostiles emerge. Getting bit deals **1 Heart** of damage, flashes your screen with a deep red vignette, and triggers camera trauma shake.

### Warning RED Nameplates
All hostile entities (Zombies, Goblins, Gargoyles, Sharks) now render with aggressive **Crimson Red Nameplates** displaying their names above their heads.
*   **Gargoyle Flight Tracking:** The Gargoyle's nameplate dynamically tracks its model vertical position in real-time, gliding smoothly up and down during flight sways.

### The Golem & Guard Defenders
Villages are actively protected by tactical defenders (Guards and Golems) which register themselves into a shared **Alert Alarm Network** upon spawning.
*   **Coordinated Alarm Interceptions:** Struck civilians immediately broadcast a proximity alarm. Nearby protectors within a 30m radius will break their patrols, sprint to the rescue, and intercept the attacker.
*   **Iron Golems:** Colossal stone giants covered in ivy. If a zombie comes near, they execute a heavy double-arm launch attack, dealing massive damage and throwing the zombie **9.5 meters into the air**.
*   **Guards:** Armored knights with a sheathed iron sword and wooden shield. They proactively draw their weapons, sprint towards hostiles, and execute coordinated striking overwatch cooldowns.

### Player Combat, Karma & Polymorphic Loot
1.  Press **Key 8** to hold your **Wooden Sword** (Slot 7).
2.  Aim at a zombie and **Left-Click** to swing. The action plays a metallic `hit_sword` swish sound and a physical hand animation.
3.  **Village Reputation (Karma Engine):** Hitting peaceful civilians deducts `-15 reputation points` from your karma, and killing them deducts an additional `-35 points` (total of `-50`). If your reputation falls to **Wanted Outlaw** status (reputation <= -50), all village guards and golems will become hostile and attack you on sight!
4.  **Trade Price Adjustments:** Your karma modifies Merchant bartering prices dynamically: high reputation grants up to **30% discounts**, while poor reputation increases prices by up to 30%.
5.  Zombies take 3 hits to defeat. Upon death, enemies and fauna shrink, emit a puff of grey GPU smoke, and polymorphically drop loot (Meat, Leaves, Sand, Lava) directly into your bag.

---

## 8. Backpack Inventory & Item Inspector (`I`)

Pressing **`I`** freezes the gameplay physics and opens a detailed **Backpack Inventory & Inspector** overlay.

### 24-Slot Storage & Auto-Sorting
*   **Decoupled Grid Slot Widgets:** Inventory slots use isolated `InventorySlotWidget` nodes, completely separating cell drawing and drag-and-drop mechanics from container layouts.
*   **Stacking:** Items stack dynamically up to 64 units per slot.
*   **Sequential Swapping:** Click Slot A (glows in gold), then click Slot B to instantly swap their contents.
*   **⚡ AUTO-SORT:** Click the "SORT" button in the Backpack header. The engine will instantly consolidate all fragmented stacks and sort your backpack by Item ID in ascending order, leaving your active Hotbar completely untouched for combat safety!

### The Item Inspector
Clicking any item displays its Lore Tooltip, Stock quantity, and Action buttons. Consumable foods like Fried Chicken can be eaten directly from the menu by clicking **CONSUME**, healing 1 Heart instantly.

---

## 9. Blueprint Taller & Crafting Workshop (`C`)

Pressing **`C`** opens a dual-pane **Blueprint Taller & Crafting Workshop** overlay, parsed entirely from external JSON data files.

*   **Inputs Checklist:** Scans your entire 24-slot inventory dynamically to aggregate your stock, showing a green checkmark (`✔`) if you have enough materials.
*   **Corrected Checklist Verification:** The checklist strictly queries cumulative total stocks globally using `get_item_total_quantity()`, resolving old slot-matching lookup discrepancies.
*   **Fabricate Action:** Clicking the green "Fabricate" button consumes the inputs globally, grants the crafted outcome, triggers a viewmodel hand-swing, plays a satisfying `craft_clink` audio cue, and pops a sliding success notification.

### Recipe Quick Reference:
*   **Organic Composting:** `3x Leaves` ➔ `1x Dirt`
*   **Sod Cultivation:** `2x Dirt` + `1x Leaves` ➔ `2x Grass`
*   **Soil Pulverizer:** `1x Stone` ➔ `3x Dirt`
*   **Igneous Cobbling:** `4x Dirt` + `1x Lava` ➔ `4x Stone`
*   **Geothermal Charcoal Fuel:** `6x Wood` + `1x Lava` ➔ `3x Lava Buckets`
*   **Reinforced Stone Slabs:** `2x Stone` + `1x Dirt` ➔ `3x Stone Slabs (Half-height)`
*   **Composite Planks:** `2x Wood` + `1x Stone` ➔ `4x Wood`
*   **Wooden Sword:** `4x Wood` ➔ `1x Wooden Sword`
*   **Emergency Herbal Rations:** `10x Leaves` + `1x Wood` ➔ `1x Fried Chicken`

---

## 10. Handcrafted Global Mega-Structures (3D Overhaul)
The world features 5 handcrafted global landmarks, seamlessly integrated with sloped-terrain blending:
*   **The Grand Castle `[200, 200]`:** A colossal two-story stone fortress featuring a majestic double-height Throne Hall, symmetrical rising double-wing staircases, private chambers (King's bedroom with cloud sheets, Queen's suite, and War Council), a high-security Royal Treasury, and crenellated rooftop battlements. Fast-travel drops are calibrated on the outer stone bridge.
*   **The Seaport & Galleon `[-150, 0]`:** A coastal port featuring wood-planked boardwalks, stacked cargo, a cozy two-story harbor tavern ("The Salty Sailor Inn" with bar and rooms), and a moored three-deck Galleon Ship containing crew bunks, cargo hold, and a captain's cabin with glass popa windows.
*   **The Nether Fortress `[-300, -300]`:** A tattered volcanic brick citadel flanked by hot concentric lava canals and stone bridges, guarding a colossal double-height central Portal Sanctuary and an elevated treasure pedestal.
*   **Steve's Settlement `[300, -300]`:** A playable village spanned by a giant mossy parabolic stone archway, central water fountain, irrigated wheat fields, a two-story log lodge, and a medieval windmill with fully accessible interior floors.
*   **Desert Oasis Pyramid `[-150, 250]`:** A stepped 10-tier sandstone pyramid built over water, housing a central pharaoh's sarcophagus altar, comfortable side stone stairs, and an elevated treasure vault under a glowing apex lighthouse.

---

## 11. The Automated Delta-Save Pipeline

CraftDomain features a silent, zero-stutter background **Delta-Save** process. You never have to manually click a save button:

1.  Pressing **Escape** pauses the game, opens the sleek Pause Menu, and triggers the save sequence.
2.  The engine instantly gathers your current `(X, Y, Z)` position, camera look angles, world seed, celestial calendar day (persisting moon phases), active quest states, and full 24-slot backpack item quantities, writing them to `user://world_save/global_save.json`.
3.  Simultaneously, any blocks you broke or placed are gathered as localized modification deltas and saved directly to chunk files on disk (e.g., `chunk_-21_1_10.json`).

---

## 12. Dynamic Cursor Release Engine (`Left Alt` Hold)

To easily bridge the gap between first-person look controls and HUD-element interactions:
*   **Holding `Left Alt`:** Freezes camera rotation and reveals the hardware mouse pointer. You can move the pointer freely to click on the HUD shortcut icons (`🎒` to open inventory or `🛠️` to open the crafting workshop).
*   **Releasing `Left Alt` Hides Pointer:** Locks it back into first-person rotation mode. 
*   **Open-Close Safety Hook:** Releasing `Left Alt` will *not* lock the cursor if any overlay window (Backpack, Workshop, Map, Pause, or Dialogue) is actively open on the screen.
