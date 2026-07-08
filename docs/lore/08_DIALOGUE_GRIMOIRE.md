# Dolores Dialogue Grimoire: Branching Conversations & Barter Tables GDD
*NPC Dialogue Trees, Ambient Bark Lines & Market Trade Systems GDD by Enrique González Gutiérrez (enrique.gonzalez.gutierrez@gmail.com)*

This sacred grimoire compiles all written dialogue trees, conditional ambient bark lines, and merchant bartering tables within the universe of Dolores. All user interface dialogue layers and localization files must align strictly with the scripts established in this document.

---

## 🧑 PART I: CIVILIAN CHAT REGISTRY (AMBIENT BARK LINES)

---

### 1. The Villagers (Common Civilians)

*   **Sunny Day (Golden Bazaar Plains):**
	*   *"Our farmers are working hard to sow seeds and harvest wheat for the bakery. Have you smelled the fresh bread today?"*
	*   *"If you are hurt, eat some of Valerius's Fried Chicken. It heals you instantly! I don't know what herbs he puts in it, but it works."*
	*   *"Have you seen the Grand Stone Castle to the east? It is a massive structure. The Mayor says it holds the history of our present."*
*   **Nighttime Warning (All Terrestrial Biomes):**
	*   *"Shh... keep your voice down! It is dark. Cave zombies roam the grasslands at night. Stay near Aethelgard's path!"*
	*   *"The wind carries the sound of grinding stone tonight... the necrotic rifts are opening in the outer fields."*
*   **Frostbite Glaciers (Glacial Shelf):**
	*   *"Brr... it's freezing up here. My parkas are barely holding the cold! I can feel the ice trying to freeze my very pixels."*
*   **Neon Ruins (Cyber Basin):**
	*   *"These cian structures are radiating high-energy data blocks. Remarkable... yet highly unsettling for an organic mind."*
*   **Swamp of Sighs (Mist Bay):**
	*   *"The mud in this Swamp of Sighs is thick and heavy, but the local blue mushrooms are great for the alchemical cauldrons."*
*   **Cloud Kingdom (Floating Isles):**
	*   *"We are floating so high! The nubes are incredibly soft to walk on. It feels like standing on woven space-time fabric."*

---

### 2. The Guard Knights (Defenders)

*   **Patrol Duty (Golden Bazaar Plains):**
	*   *"I patrol the village borders to ensure the safety of our farmers and traders. Keep your sword sheathed, stranger."*
	*   *"If you hold a Wooden Sword, Left-Click to swing and attack. It will push the necrotic husks back with knockback!"*
*   **Night Defense (All Terrestrial Biomes):**
	*   *"Stay behind my shield! I will cut down any cave zombie that approaches. Let Aethelgard crush the massive ones!"*
*   **Glacier Patrol (Frostbite Glaciers):**
	*   *"My steel-plated armor is freezing cold, but my blade is sharp. No glitched giants are getting past my watch."*
*   **Cyber-Signatures (Neon Ruins):**
	*   *"Detecting high-frequency cybernetic signatures... Security levels normal. Mind your step around the active cian conduits."*

---

### 3. The Farmers (Cultivators)

*   **Field Work (Golden Bazaar Plains):**
	*   *"When wheat turns golden, it is ready. Harvest it to get both wheat grains and seeds! Don't let the necrosis rot it."*
	*   *"Sow seeds on fertile grass or dirt. Always keep them hydrated near water canals! Plants need the moisture of the Present."*
*   **Winter Crop Stress (Frostbite Glaciers):**
	*   *"Growing crops on frozen ice shelves is hard work, but we manage by tilling near the hot thermal vents!"*
*   **Cyber Photosynthesis (Neon Ruins):**
	*   *"These glowing cian paths seem to accelerate crop photosynthesis! The wheat grows faster, but it tastes slightly metallic..."*

---

## 🎭 PART II: CINEMATIC BRANCHING DIALOGUES (MASTER TREES)

---

### 1. Maelor, the Last Weaver (Ancestral Mayor)

```text
			   [ INTERACT (Right-Click) ]
							│
							▼
			  [ MAIN NODE: Intro Dialogue ]
							│
		 ┌──────────────────┼──────────────────┐
		 ▼ Option A         ▼ Option B         ▼ Option C
[ Ask about Necrosis ]  [ Ask about Golem ]  [ Farewell/Close ]
		 │                  │                  │
		 ▼                  ▼                  ▼
 [ Loops to Main ]    [ Triggers Quest 2 ]  [ Closes UI ]
```

*   **Entry Node (`villager_intro_temp`):**
	*   *Maelor:* "A stranger... your code, it is stable. *Grips his temples as a static hiss escapes his lips* ...01100100. I am Maelor, the last who remembers the loom. The Null Void is unweaving our Present. My memories, my people, our crops... they are dissolving into static."
*   **Player Option A:** "What is this 'Null Void' and the 'Necrosis'?"
	*   *Maelor:* "It is the unweaving of Dolores. Malakor, a rogue Weaver of the Loom, opened the Nether Breach at coordinates `[-300, -300]`. He believes a glitched, chaotic end is better than a perfect, silent future. The necrotic magma resuscitates the dead into Cave Zombies to rot our present. We are dying, Nomad."
	*   *Exit Option:* "How do we fight back?" *(Navigates to Option B)*
*   **Player Option B:** "How do we activate the Iron Sentinel?"
	*   *Maelor:* "Aethelgard's basalt body is cold. His core was depleted during the first siege. Speak with Valerius, the alchemist at the market. He holds the **Golem's Fire Core**, but his geothermal fryers are offline... and his daughter's time is running out. Help him, and Aethelgard will rise."
	*   *Action:* Activates Quest `fuel_fryer` in the player's quest log.
*   **Player Option C:** "I must find a way back to my ship."
    *   *Maelor:* "There is no sea to sail, Nomad. The horizon is dissolving into static. If Dolores falls, your ship, your home, and your very existence will be compiled into nothingness. Help us, and the loom may weave you a path home."
    *   *Exit Option:* "I will find Valerius." *(Closes Dialogue UI)*

---

### 2. Valerius, the Rogue Alchemist (The Fryer Merchant)

*   **Entry Node (`merchant_intro`):**
	*   *Valerius:* "*Visor blinks wildly* Greedy hum! Smell that geothermal heat! Stranger, my fryer is cold and my chicken business is ruined. The zombies have us surrounded. If you deliver me a bucket of hot, volatile lava to ignite my fryers, I will trade you my famous therapeutic Fried Chicken... and the Golem's Fire Core!"
*   **Player Option A:** "Why is 'Fried Chicken' so important during a zombie apocalypse?"
	*   *Valerius:* "*Whispers frantically, looking around* Sss! Keep quiet! It's not for the villagers... it's for my daughter, Lyra. She was caught in a Glitch Rift. Her arm is pixelating... dissolving into static. The high-frequency alchemical heat of the geothermal fryer is the only thing that slows down the necrosis! The chicken is coated in alchemical herbs to keep her stable! I need that lava, Nomad!"
	*   *Exit Option:* "I will go find the lava." *(Closes Dialogue UI)*
*   **Player Option B (Only if holding Lava Bucket):** "I have the Geothermal Lava. Let's make the trade."
    *   *Action:* Executes `execute_id_trade()`. Consumes 1x Lava Bucket (`ID 15`). Grants 1x Fried Chicken (`ID 16`) and 1x Golem Core.
	*   *Valerius:* "*Executes an elastic vertical leap of joy!* Greedy happiness! This lava is burning perfectly! Smm... smell those herbs sizzle! *Pours the lava into the reactor behind his stall, stabilizing his daughter's pixelated arm* Thank you, Nomad. Her code is stable. She'll survive another day. Take the Golem's Core! Place it in Aethelgard's chest in the plaza!"
	*   *Action:* Activates Quest `plains_defender` in the player's quest log.

---

## 🪙 PART III: THE BARTER TRADE TABLES (THE REPUTATION ECONOMY)

The pricing and availability of Valerius's alchemical market are dynamically modified by the player's active **Village Reputation (Karma)** score:

*   **Reputation: WANTED OUTLAW (Score <= -50)**
	*   *Merchant Reaction:* Refuses to trade. Emits anxious hums and yells for the Guard Knights.
	*   *Guard Reaction:* Instantly hostile. Draws swords and sprints to attack on sight.
*   **Reputation: NEUTRAL STRANGER (Score 0)**
	*   *Barter Multiplier:* 1.0x (Standard prices).
*   **Reputation: HERO OF DOLORES (Score >= 75)**
	*   *Barter Multiplier:* 0.70x (30% discount on all trades).

### The Alchemical Trade Table:

| Player Gives (Input ID) | Quantity | Merchant Gives (Output ID) | Quantity | Alchemical Purpose |
| :--- | :---: | :--- | :---: | :--- |
| **Volatile Lava Bucket (ID 15)** | 1 | **Therapeutic Fried Chicken (ID 16)** | 1 | Slows down necrosis / Restores 1 Heart |
| **Craggy Stone Block (ID 1)** | 1 | **Phosphorus Shards (ID 30)** | 2 | Wishing Well token / Glowstone crafting |
| **Shrubbery Leaves (ID 5)** | 10 | **Fertile Dirt Block (ID 2)** | 1 | Organic Composting / Crop soil |
| **Chrono-Oak Wood (ID 4)** | 6 | **Geothermal Charcoal (ID 5)** | 3 | Geothermal reactor fuel |
