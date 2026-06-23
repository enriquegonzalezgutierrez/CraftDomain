# CraftDomain

![MainMenu Background](src/Infrastructure/UI/Assets/menu_background.png)

A high-performance, infinite voxel sandbox game engine built in **Godot 4.6.3** following **Domain-Driven Design (DDD)** principles and strict **SOLID** software engineering compliance.

## Project Metadata
* **Author:** Enrique González Gutiérrez
* **Contact:** enrique.gonzalez.gutierrez@gmail.com
* **Architecture:** Domain-Driven Design (DDD) & Single Responsibility Principle (SRP)
* **Assets:** Programmatic 3D box compositions (animals/villagers), procedural shading, and generative multi-octave FBM landscapes.

## High-Performance Architectural Optimizations
* **Zero Main-Thread Loop Rendering:** All mathematical coordinate loops ($16 \times 16 \times 16 = 4096$ iterations per chunk) are offloaded entirely to background threads (`WorkerThreadPool`). The main thread receives pre-compiled GPU buffers, loading chunks at a constant, stutter-free frame-rate.
* **Compound Box-Shape Physics:** Bypasses Godot's triangle-seam snagging bug by dynamically registering pre-calculated `BoxShape3D` resources directly into a single `StaticBody3D` physics server owner, allowing perfectly smooth sliding and jumping.
* **Bi-Layered Fractal FBM Biomes:** Terrain uses Fractal Brownian Motion (FBM) with 4 detail octaves, creating low-lying Ocean shores, flat plain Meadows, and towering rugged Mountain peaks dynamically.
* **Asynchronous Delta-Saving Persistence:** Edits are stored on a per-chunk modification delta basis in small, independent JSON files inside the operating system's safe `user://` directory, preventing file bloat and corruption.

## Directory Layout
* `src/Core/Bootstrap`: Application entry point and Dependency Injection (`Bootstrap.gd`).
* `src/Domain/World`: Core logical models (`Chunk.gd`, `BlockType.gd`, `BlockDefinition.gd`, `WorldState.gd`, `StructureLibrary.gd`, `BiomeService.gd`).
* `src/Infrastructure/World`: Thread-safe terrain generators and chunk managers (`WorldController.gd`).
* `src/Infrastructure/Rendering`: GPU-instanced visual mesh handlers (`ChunkNode.gd`).
* `src/Infrastructure/Player`: Camera, raycasting, physics, and gravity controllers (`PlayerController.gd`).
* `src/Infrastructure/Life`: Procedural box-composition active AI mobs (`PassiveEntity.gd`).
* `src/Infrastructure/UI`: Glassmorphic circular minimaps, menu loops, and hotbar presentation overlays (`MainMenu.gd`, `PlayerHUD.gd`).
* `src/Infrastructure/Persistence`: Concrete JSON world save-and-load repositories (`DiskWorldRepository.gd`).
* `src/Infrastructure/Audio`: Programmatic soundtrack players and parallel cinematic crossfaders (`AudioService.gd`).

## License
This project is licensed under the MIT License.
