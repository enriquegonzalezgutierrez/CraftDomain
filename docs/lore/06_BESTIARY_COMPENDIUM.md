# Dolores Bestiary: Living Fauna & Corrupted Husks Compendium GDD
*Creature Design, Behavior AI & Combat Telemetry GDD by Enrique González Gutiérrez (enrique.gonzalez.gutierrez@gmail.com)*

This compendium serves as the absolute physical, behavioral, and narrative guide for all living species and corrupted entities inhabiting the world of Dolores. All physics settings, collision shapes, animations, and loot tables must align strictly with the specifications compiled in this Bestiary.

---

## 🌾 PART I: THE PASSIVE WILDLIFE (FAUNA OF DOLORES)

---

### 1. The Wild Pig (`ID 0` - *Porcus Voxelus*)

```text
Classification: Passive Terrestrial Fauna
Habitat: Terrestrial (Grasslands, Forests, Badlands)
Collision Size: Width 0.60m, Height 0.75m, Length 0.65m (Cylinder)
Visual Scale: 9.4485x (Calibrated from micro-GLTF baseline)
Rotation Offset: Y = 90 degrees (Faces forward along -Z axis)
Loot Drops: 1x Fried Chicken (Meat proxy)
```

*   **Lore & Origin:** The Wild Pig is the most common organic creature in Dolores. Woven during the dawn of the Present era, they are the literal embodiment of fertile earth. They are robust, clumsy, and spend their days tilling the topsoil of the Golden Bazaar with their snouts, looking for roots and tilled wheat seeds.
*   **Behavioral AI (Wandering & Panic):**
	*   *Normal State:* Voxel pigs wander aimlessly in a 12-meter radius of their spawn coordinates. They prefer grassy paths and actively avoid stepping into deep water basins or walking off cliffs.
	*   *Panic State:* If attacked, they enter an immediate high-frequency panic state for 4.5 seconds. They run in random safe directions, their body bobbing at high frequencies, and emit squeals of distress.
*   **Physical Boundary Constraint:**
	*   The absolute boundary forcefield inside `PassiveEntity.gd` projects their next step. If a pig tries to walk into a `WATER` or `LAVA` block, its horizontal velocity is instantly nullified to `0.0`. It collides with the water surface as if it were a solid glass wall, preventing it from ever falling in.

---

### 2. The Sea Turtle (`ID 201` - *Chelonia Marina*)

```text
Classification: Passive Amphibious Fauna
Habitat: Amphibious (Ocean Water, Sandy Beach Shores, Swamps)
Collision Size: Width 0.30m, Height 0.35m, Length 0.65m (Cylinder)
Visual Scale: 0.0570x (Calibrated)
Rotation Offset: Y = 180 degrees (Faces forward along -Z axis)
Loot Drops: 1x Sand Block
```

*   **Lore & Origin:** The Sea Turtle is an ancient, slow-moving species woven at the boundary where the ocean meets the land. They are the sapes of the shore, carrying patterns on their shells that represent the coordinate grid lines of the first chunk loaders.
*   **Behavioral AI (Amphibious Transition):**
	*   *Water Swimming:* Inside water blocks, they glide smoothly with a gentle sinusoidal swimming animation. Their gravity is disabled, and they float at the water surface.
	*   *Land Crawling:* If they crawl onto beach sand (`BLOCK_SAND`), they suffer a 50% movement speed penalty. Their leg animations change to a slow, laborious crawl, and standard gravity is applied to keep them grounded.
*   **Physical Boundary Constraint:**
	*   The amphibious forcefield allows them to step only on `WATER`, `SAND`, or `MUD`. If they try to crawl onto grass or stone cliffs, the forcefield nullifies their velocity, keeping them locked to the coastal biome.

---

### 3. The Domestic Cat (`ID 206` - *Felis Domesticus*)

```text
Classification: Passive Terrestrial Fauna
Habitat: Terrestrial (Plains, Village, Badlands)
Collision Size: Width 0.20m, Height 0.36m, Length 0.50m (Cylinder)
Visual Scale: 1.0x (Calibrated)
Rotation Offset: Y = 180 degrees
Loot Drops: 1x Fried Chicken (Meat proxy)
```

*   **Lore & Origin:** Woven as companions for the Weavers, Domestic Cats are small, highly agile creatures that thrive near village outposts. They possess a natural alignment to the Present era, which makes them highly sensitive to the temporal anomalies of the Null void.
*   **Behavioral AI (Village Attachment & Blight Detection):**
	*   *Village Roaming:* Cats prefer to stay within a 15-meter radius of active cabins and merchant stalls. They sleep near campfires during the night, purring softly.
	*   *Blight Detection:* If a Glitch Rift or Cave Zombie approaches the village, the cat's fur stands on end. They hiss, run into the closest shelter node, and stay hidden under beds until the threat is purged.

---

### 4. The Colossal Elephant (`ID 209` - *Elephas Colossus*)

```text
Classification: Passive Terrestrial Fauna
Habitat: Terrestrial (Red Sandstone Canyons, Savanna)
Collision Size: Width 3.30m, Height 3.50m, Length 4.00m (Colossal Cylinder)
Visual Scale: 3.0012x (Calibrated)
Rotation Offset: Y = 90 degrees
Loot Drops: 2x Fried Chicken (Meat proxy), 1x Stone Block (Tusk ivory)
```

*   **Lore & Origin:** The Colossal Elephant is the largest organic creature in Dolores. Woven during the first creation cycles, they act as living mountains. Their bones are made of craggy stone, and their heavy tusks are carved of ancient sandstone.
*   **Behavioral AI (Earth-Shaking Walk):**
    *   They walk with massive, slow strides. Every step they take triggers a localized screen shake effect if the player is within a 10-meter radius, and emits a deep, thudding sound.
    *   Due to their massive size, they are completely immune to standard zombie knockback forces.
*   **Physical Scaling Unification:**
    *   The base class `PassiveEntity.gd` automatically scales their collision cylinder to a massive `3.50m` height and `3.30m` width, and projects their nameplate `3.85m` high in the air, ensuring it floats clearly above their ears.

---

## ☠️ PART II: THE CORRUPTED HOSTILES (THE NULL HUSKS)

---

### 5. The Cave Zombie (`ID 10` - *Mortuus Voxelus*)

```text
Classification: Hostile Terrestrial Husk
Habitat: Terrestrial (Caves, Nighttime Plains, Nether Outpost)
Collision Size: Width 0.60m, Height 1.80m, Length 0.60m (Cylinder)
Visual Scale: 1.6635x (Calibrated)
Rotation Offset: Y = 180 degrees
Loot Drops: 1x Lava Bucket (Quest transaction deduction), 1x Bricks (Fortress debris)
```

*   **Lore & Origin:** The Cave Zombie is the primary military husk of Malakor. They are reanimated corpses of fallen Weavers, their bodies petrified into grey stone and tattered blue clothes. Their flesh has been corrupted by the Null void, glowing with purple glitched scars.
*   **Behavioral AI (Chasing & Wall Steering):**
    *   *Scent Tracking:* If the player is within a 16-meter radius, the zombie locks onto their coordinate, emits a terrifying, glitched roar, and sprints towards them.
	*   *Real-time Wall Flanking (Steering):* If the zombie hits a wall while chasing the player, the code projects its chase vector perpendicular to the wall's normal plane. The zombie **automatically slides sideways and skirts around corners and obstacles** to reach the player, instead of getting stuck pushing forward!
*   **Combat Telemetry & Weaknesses:**
	*   *Health:* 3 Hearts (6 HP).
	*   *Attack:* Deals 1.0 Heart of damage and applies 4.5m of diagonal knockback on bite.
	*   *Weakness:* Takes +10% extra damage and suffers double knockback when struck by the **Silicon Saber** or **Chrono-Scythe**, as their high-frequency code disrupts the Null corruption binding its limbs.

---

### 6. The Great White Shark (`ID 11` - *Carcharodon Glitchus*)

```text
Classification: Hostile Aquatic Husk
Habitat: Aquatic (Deep Ocean, Swamp Water)
Collision Size: Width 0.85m, Height 1.80m, Length 1.10m (Cylinder)
Visual Scale: 1.8366x (Calibrated)
Rotation Offset: Y = -90 degrees
Loot Drops: 1x Sand Block
```

*   **Lore & Origin:** The Great White Shark is the terrifying predator of the Bay of Sails. Corrupted by the purple temporal bleed of the Nether Portal, its teeth have become glitched blades of obsidian, capable of unweaving the wooden hulls of fishing galleons.
*   **Behavioral AI (Scent Tracking & Boundary Lock):**
	*   *Scent Tracking:* If the player swims into the ocean within a 20-meter radius, the shark senses their vibrations, its dorsal fin cutting through the water as it accelerates.
	*   *Absolute Boundary Lock:* The absolute boundary forcefield projects its next step. If the shark swims towards a sandy beach, the forcefield nullifies its horizontal speed, keeping it strictly locked inside the water volume.
*   **Combat Telemetry:**
	*   *Health:* 4 Hearts (8 HP).
	*   *Attack:* Leaps out of the water to bite, dealing 1.5 Hearts of damage and destroying wooden boats instantly.

---

### 7. The Gothic Gargoyle (`ID 12` - *Statua Nocturna*)

```text
Classification: Hostile Terrestrial / Airborne Husk
Habitat: Terrestrial (Mountain Peaks, Ice Temple, Nighttime Plains)
Collision Size: Width 2.35m, Height 1.80m, Length 1.10m (Cylinder)
Visual Scale: 2.3504x (Calibrated)
Rotation Offset: Y = 90 degrees
Loot Drops: 1x Stone Block (Rusted stone debris)
```

*   **Lore & Origin:** Built of rusted basalt and gargoyle iron, these gothic sentinels were crafted to guard the high spires of the Past. Corrupted by Malakor, they have become terrifying nocturnal hunters.
*   **Behavioral AI (The Day/Night State Machine):**
	*   *Daytime State (STONE):* The gargoyle freezes, its material shifting recursively to solid, matte grey stone. It falls flat on the ground. Its AI is completely disabled, and it acts as an invulnerable, collidable statue.
	*   *Nighttime State (AWAKE):* As the sun sets, its joints ignite with a purple glow. It awakens, floats neutrally at +2.5m altitude using smooth sinusoidal hover sways, and aggressively pursues the player.
*   **Combat Telemetry:**
	*   *Health:* 6 Hearts (12 HP - extremely high stone defense).
	*   *Attack:* Swoops down to slash, dealing 1.0 Heart of damage.

---

### 8. The Sneaky Goblin (`ID 13` - *Goblinius Furvus*)

```text
Classification: Hostile Terrestrial Husk
Habitat: Terrestrial (Craggy Caves, Nether Outpost)
Collision Size: Width 0.50m, Height 0.75m, Length 0.50m (Cylinder)
Visual Scale: 0.75x (Calibrated)
Rotation Offset: Y = 90 degrees
Loot Drops: 1x Stone Block (Debris)
```

*   **Lore & Origin:** Goblins are small, rapid-trotting cave scavengers. They are obsessed with collecting glowing gold and cian data shards, and wander deep caverns under the Craggy Peaks.
*   **Behavioral AI (Alarm Network & Skirmish):**
	*   *Skirmish Tactics:* Goblins are fragile. They run fast, hit the player for 0.5 Hearts of damage, and quickly run back to hide behind rocks.
	*   *Coordinated Alarms:* If struck, the Goblin broadcasts a proximity alarm via `AlertNetworkService`. Nearby Cave Zombies and Gargoyles within a 30m radius break their patrols and sprint to coordinate a pincer attack on the player.
