# Dolores Chronicles: Guild Bulletin & Side Quests Design GDD
*Narrative Design & Optional Content Mapping by Enrique González Gutiérrez (enrique.gonzalez.gutierrez@gmail.com)*

This optional content document outlines the non-linear side stories, guild contracts, and environmental adventures available in Dolores. These quests enrich the world-building, flesh out minor NPCs, and reward the player with unique utility items (gliders, alchemical recipes, and permanent bartering perks).

---

## ⛰️ SIDE QUEST I: THE MINER'S HELMET (CRAGGY PEAKS)

### 1. Quest Overview & Lore
*   **Quest Giver:** Barnaby, the Veteran Miner (`MinerEntity` spawned in the Craggy Peaks outpost).
*   **Unlock Condition:** Completing Act I, Chapter III (Golem Activation).
*   **Narrative Hook:** Barnaby, a veteran stone-cutter of the peaks, descended into the deepest, unmapped shafts of the Craggy Peaks in search of a legendary coal vein. While deep underground, his helmet’s 3D Spotlight battery died, leaving him in pitch-black darkness. To make matters worse, a tribe of sneaky Goblins (`ID 13`) has surrounded his position, tracking his breathing in the dark.
*   **Reward:** The **Miner's Spotlight Helmet** (a cosmetic headgear item that projects a real-time 3D Spotlight beam into cave shadows when equipped).

### 2. Environmental & Atmosfere Design
*   **The Deep Shaft:** The quest takes place inside a narrow, vertical cave system under the Craggy Peaks. There is zero ambient light; the player cannot see more than 1 meter in front of them without torches.
*   **Soundscape:** The deep, echoey dripping of water, the distant, mischievous cackles of Goblins whispering in the dark, and Barnaby's heavy, terrified breathing.

### 3. Step-by-Step Gameplay Mechanics
1.  **Accepting the Quest:** The player speaks with the Miner's wife at the Bazaar. She points them toward the northwestern cave entrance.
2.  **Illumination Navigation:** The player must navigate the dark caverns. They must craft and place **Glowstone blocks** (`BLOCK_GLOWSTONE`) or Torches to illuminate the path and prevent falling into bottomless ravines.
3.  **Goblin Ambush:** Upon reaching Barnaby's location, the Goblins attack in waves. The player must fight them off in the dark, using the glowing light of the placed blocks to track the Goblins' movements as they slide around pillars using *Wall Steering*.
4.  **Rescuing Barnaby:** The player interacts with Barnaby, giving him a battery core (crafted from a glowstone block and coal). His helmet light ignites, and he walks back to the surface using the compiled A* navigation path.

### 4. Cinematic Dialogue Script (Barnaby's Rescue)

*(The player finds Barnaby sitting in a dark corner of the cave, hugging his knees as his helmet light flickers and dies)*

*   **Barnaby (The Miner):**
    > "*Whispers terrified*... Sss! Keep quiet! They are in the shadows... * Engranajes de pico clack* ...I can hear their claws clicking on the stone. My light is dead, Nomad. I am trapped. Please, tell my wife I tried to find the vein..."

*(The player hands over the drafted battery core by right-clicking him)*

*   **Barnaby (Reactivated):**
	> "*His helmet light ignites with a blinding, warm white beam of light* ¡By the past! Light! *Swings his pickaxe with joy* You saved my skin, Nomad! Look at those Goblins run from the glare! *Pats your shoulder* Let's get out of this pit. Meet me at the surface, and my forge is yours!"

---

## 🌲 SIDE QUEST II: THE SPECTRALLY CORRUPTED FAWN (REDWOOD FOREST)

### 1. Quest Overview & Lore
*   **Quest Giver:** Elenari, the Druid Scholar (`DruidEntity` in the Redwood Sanctuary).
*   **Unlock Condition:** Completing Act II, Chapter V (Canopy of Whispers).
*   **Narrative Hook:** A rare, sacred creature of the woods—the Spectral Fawn—has wandered into a heavily glitched sector on the forest boundary. The Null corruption is unweaving its code, causing it to glitch between physical existence and transparent static. Elenari cannot enter the glitched zone due to her organic vulnerability, and begs the Chrono-Nomad to rescue the beast.
*   **Reward:** **The Voxel Glider blueprint** (allowing the player to craft the high-altitude glider using redwood planks and cloud fabric).

### 2. Environmental & Gameplay Mechanics
*   **The Glitched Glade:** A sector of the forest where the gravity is unstable and the ground blocks are dissolving into static. 
*   **Mechanics:**
    *   The player must track the fawn's glowing green footprints across the forest floor.
    *   The fawn (`ID 204` Fox proxy) is panicking, running wildly. 
    *   The player must use their **Chrono-Scythe** (or place compost blocks) to temporarily stabilize the Glitch Rifts, creating a safe, uncorrupted pathway for the fawn to cross.
    *   Once the pathway is clear, the player must gently guide the fawn back to the Redwood Sanctuary.

### 3. Cinematic Dialogue Script (Elenari's Gratitude)

*(The player returns the glowing fawn safely to the sanctuary platforms)*

*   **Elenari (The Druid Scholar):**
	> "The forest breathes a sigh of relief, Nomad. The fawn's code is clean... *Stroke's the fawn's glowing fur* ...I felt the static tearing at its spirit from here. You have proven that your outsider code is a force of healing, not just destruction.
    > 
    > Take this. *Hands over an ancient scroll* It is the design of the Voxel Glider. Use the wind of the canopies to soar across the void. May the Present guide your flight."

---

## 🌊 SIDE QUEST III: THE TERROR OF THE DEEP (BAY OF SAILS)

### 1. Quest Overview & Lore
*   **Quest Giver:** Captain Barnaby (The Port Master at Harbor City, `X:-150, Z:0`).
*   **Unlock Condition:** Completing Act III, Chapter VII (Mud and Alchemy).
*   **Narrative Hook:** A colossal, Null-corrupted Great White Shark—known as the *Glitched Maw*—has nested in the deep waters of the Bay of Sails. It is attacking the fishing galleons and tearing down the wooden harbor piers. Its body is covered in glowing purple scars, and its bite glitch-deletes any blocks it touches.
*   **Reward:** **The Shark Tooth Talisman** (an accessory that grants +15% horizontal swimming speed and unlimited breath in deep water).

### 2. Environmental & Gameplay Mechanics
*   **The Deep Bay:** The player must take a wooden boat out into the deep ocean.
*   **The Hunt:**
    *   The player must craft **Volatile Meat Bait** (combining raw meat and geothermal lava) and drop it into the water to lure the Glitched Maw.
    *   The beast (`ID 11` Shark) attacks, leaping out of the water to smash your boat.
    *   The player must engage in high-impact naval/swimming combat, using their sword and arrows to strike its gills while avoiding its glitched bite (which deletes blocks and deals 1.5 Hearts of damage).
    *   Defeating the beast yields the **Glitched Shark Tooth**.

### 3. Cinematic Scene: The Death of the Maw
*(The player delivers the final blow. The giant shark thrashes in the water, its purple scars exploding into a spectacular show of steam and white particles, before dissolving into a chest of fine sand on the seabed)*

*   **Captain Barnaby (Over the radio/shouting from docks):**
	> "¡By the tides! You took down the Maw! *Tosses his sailor cap* I've never seen a beast that massive dissolve into stardust. The Bay is safe for the galleons once more, Nomad! Come back to the harbor, the tavern is buying your drinks tonight!"

---

## 💾 SIDE QUEST IV: THE CONDUIT OVERLOAD (NEON RUINS)

### 1. Quest Overview & Lore
*   **Quest Giver:** Sector-Unit 9, the Automated Overseer (`Android NPC` in the Silicon Forge).
*   **Unlock Condition:** Completing Act II, Chapter VII (Silicon Heist).
*   **Narrative Hook:** An ancient data-conduit beneath the Silicon Forge has suffered a massive energy feedback loop due to the temporal bleed of the Nether Breach. If the pressure is not manually vented, the entire Neon Ruins basin will explode in a high-frequency digital detonation.
*   **Reward:** **The Cyan Neon Saber** (a fast, emissive blade that glows in the dark and deals +10% damage to Null-corrupted hostiles).

### 2. Environmental & Gameplay Mechanics
*   **The Overload Chamber:** A vertical room filled with rapidly pulsing cian and magenta blocks.
*   **Mechanics:**
    *   The player must perform high-speed vertical platforming across the blocks.
    *   **The Pulsing Laser:** The blocks are safe to touch only when their color matches the player's active data-key (which swaps when they press Key 9).
    *   The player must reach three manual release valves at different heights, adjusting their console terminal values under a strict 60-second time limit before the core detonates.

### 3. Cinematic Dialogue Script (Sector-Unit 9's Report)

*(The core stabilizes. The hum of the data pipelines returns to a safe, steady pitch)*

*   **Sector-Unit 9:**
	> "SYSTEM THERMAL BALANCE: RESTORED. CURRENT PRESSURE: 0.02%. Detonation probability reduced to 0.00%. 
	> 
	> *Visor blinks with green data lines* Biometric analysis indicates your heart rate has returned to normal. Your organic infiltration was highly efficient, Nomad. Accepting reward protocol. *Ejects a glowing cian hilt* Take this. It is the Silicon Saber. May its cian frequency guide your path in the dark."
