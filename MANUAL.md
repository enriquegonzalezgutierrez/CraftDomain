# CraftDomain - Gameplay Manual
*Guide written by Enrique González Gutiérrez (enrique.gonzalez.gutierrez@gmail.com)*

Welcome to **CraftDomain**! This manual serves as a comprehensive, step-by-step guide to help you navigate, mine, build, navigate, and trade within your procedural voxel world.

---

## 1. Getting Started (The Main Menu)
When you launch the game, you will boot into a cozy, stylized **Main Menu** featuring a procedural landscape background and custom looping acoustic music.
* Click **PLAY WORLD** to begin your adventure.
* Click **EXIT GAME** to close the window.

---

## 2. Basic Controls & Movement
As soon as you enter the world, you will drop smoothly onto the grass meadow.
* **Move Around:** Use `W`, `A`, `S`, `D` or the keyboard **Arrow Keys**.
* **Look Around:** Move your mouse to look around in a full 360-degree first-person view.
* **Jump:** Press **Space** to jump over blocks.
* **Mouse Lock/Unlock (Pause & Auto-Save):** Press **Escape** at any time to unlock your mouse cursor. (See the Auto-Save section below).

---

## 3. The 2D Radar Minimap (GPS)
In the top-right corner, you have an advanced circular **GPS Radar**:
* **Yellow Arrow (Center):** Represents you. It rotates dynamically in real-time as you turn your camera.
* **Green Pixels:** Sprawling grassland Plains.
* **Bright Orange Clusters:** Active procedural Villages! Follow these orange coordinates to find settlements.

---

## 4. Mining and Building
You can interact with any block in your reach distance (5 meters). A white targeting reticle at the center of your screen shows exactly where you are aiming.

### Mining (Breaking Blocks)
* Aim at any block (Grass, Dirt, or Stone) and **Left-Click** (or press **E**).
* The block will be mined instantly, allowing you to dig tunnels deep down into stone layers.

### Building (Placing Blocks)
You have a bottom-centered **Hotbar** with 6 slots. The active selection slot is highlighted with a gold glowing border:
1. Press keys **1, 2, 3, or 4** to select your material:
   * **Slot 1 (Key 1):** Stone block
   * **Slot 2 (Key 2):** Dirt block
   * **Slot 3 (Key 3):** Wood trunk block
   * **Slot 4 (Key 4):** Shrubbery Leaves block
2. Aim at any solid surface.
3. **Right-Click** (or press **Q**) to place the selected block.

---

## 5. The Lava-Fried Chicken Economy
Your hotbar has two inventory currency slots: **Lava Buckets** (Slot 5) and **Fried Chicken** (Slot 6). You spawn with 3 Lava Buckets.

### Finding the Merchant
1. Look at your radar minimap.
2. Walk towards an **Orange Village Cluster**.
3. You will discover a rustic cabin. Standing beside the cabin is a **Purple-Robed Merchant Villager** with a golden apron.

### Trading Transaction
1. Press **Key 5** on your keyboard to hold your **LAVA BUCKETS**. (The HUD text above the hotbar will display: `[ LAVA BUCKETS: 3 ]`).
2. Walk up to the Merchant and aim at his body.
3. **Right-Click** (or press **Q**) on the Merchant.
4. The Merchant will hum excitedly, **hop in the air with physical joy**, consume 1 Lava Bucket, and trade you 1 **Fried Chicken**!
5. Press **Key 6** to hold and inspect your new **FRIED CHICKENS**!

*Note: If you attempt to interact with him without holding a Lava Bucket, the developer console will print a helpful hint: `[Merchant] Hmmm? Bring me a Bucket of Lava (Key 5) to trade for my Lava-Fried Chicken!`*

---

## 6. The Silent Auto-Save System
CraftDomain utilizes an automated **Delta-Saving** pipeline. You never have to manually click "Save".
* **Triggering Save:** Every time you press **Escape** (to unlock your mouse or pause the game), the engine silently and instantly writes all your block edits, active inventory, world seed, and your coordinates/look angles to the disk.
* **Restoring Progress:** When you close and reopen the game, clicking **PLAY WORLD** on the menu will instantly restore you exactly where you paused, with your edits and inventory perfectly intact!
