# CraftDomain

A lightweight voxel game prototype built in **Godot 4.6.3** following **Domain-Driven Design (DDD)** principles and strict **SOLID** compliance.

## Project Metadata
* **Author:** Enrique González Gutiérrez
* **Contact:** enrique.gonzalez.gutierrez@gmail.com
* **Architecture:** Domain-Driven Design (DDD) & Single Responsibility Principle (SRP)
* **Assets:** None. Built entirely using programmatic 3D primitives and procedural shading.

## Architectural Highlights
* **Zero Editor Configuration:** Input bindings, viewport cameras, procedural sky settings, lighting, and materials are generated entirely through code.
* **Separation of Concerns:** 
  * `Domain`: Houses pure rules and data models (`Chunk`, `BlockType`, `BlockDefinition`, `WorldState`) independent of the graphics engine.
  * `Infrastructure`: Handles rendering, hardware instancing (`MultiMeshInstance3D`), and player input handling (`PlayerController`, `ChunkNode`).
  * `Core`: Acts as the application's Composition Root (`Bootstrap`) to manage dependencies.
* **GPU Instanced Rendering:** Uses Godot's native MultiMesh to render thousands of voxels in a single draw call with procedurally calculated shade variation.
* **Real-time Interactivity:** Programmatic raycasting for block mining (left-click) and construction (right-click) with collision boundaries updated dynamically.

## Controls
* **Movement:** `W`, `A`, `S`, `D` or `Arrow Keys`
* **Jump:** `Space`
* **Mining:** `Left-Click` or `E`
* **Building:** `Right-Click` or `Q`
* **Inventory Selection:** Keys `1` (Stone), `2` (Dirt), `3` (Wood), `4` (Leaves)
* **Mouse Lock/Unlock:** `Escape`

## License
This project is licensed under the MIT License.