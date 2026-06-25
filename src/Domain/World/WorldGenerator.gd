# ==============================================================================
# Project: CraftDomain
# Description: Domain Service responsible for procedurally carving chunk block 
#              data. Generates 10 distinct vertical voxel zones polimorphically.
#              Features a 2D Box-Blur height interpolation pass to create smooth,
#              walkable ramps between biomes, eliminating inaccessible walls.
#              Injects organic scatter (dense forests) and landmarks strictly
#              through the dynamic StructureLibrary (OCP Compliant).
#              Fully typed statically to comply with strict GDScript warnings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/WorldGenerator.gd
# ==============================================================================
class_name WorldGenerator
extends RefCounted

var _terrain_noise: FastNoiseLite

# Maps the old Biome landmark IDs to the new OCP Structure Blueprint IDs
const LANDMARK_TO_BLUEPRINT: Dictionary = {
	1: 9, # Port Dock -> Harbor Pier (ID 9)
	2: 4, # Warp Pipe -> Warp Pipe Blueprint (ID 4)
	3: 8, # Village Cabin -> Market Cabin (ID 8)
	4: 5, # Mine Pillar -> Mine Pillar (ID 5)
	5: 6, # Ice Temple -> Ice Temple (ID 6)
	6: 7  # Neon Pyramid -> Neon Pyramid (ID 7)
}

func _init(p_seed: int = 42) -> void:
	# Primary Terrain Noise: Multi-Octave Fractal Brownian Motion (FBM)
	_terrain_noise = FastNoiseLite.new()
	_terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_terrain_noise.seed = p_seed
	_terrain_noise.frequency = 0.02
	_terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_terrain_noise.fractal_octaves = 4
	_terrain_noise.fractal_lacunarity = 2.0
	_terrain_noise.fractal_gain = 0.45

## Generates and fills the internal voxel grid of a given Chunk.
func generate_chunk(chunk: Chunk) -> void:
	var chunk_offset_x: int = chunk.position.x * Chunk.SIZE
	var chunk_offset_y: int = chunk.position.y * Chunk.SIZE
	var chunk_offset_z: int = chunk.position.z * Chunk.SIZE

	var raw_heights: Array[int] = []
	raw_heights.resize(Chunk.SIZE * Chunk.SIZE)
	
	var biome_ids: Array[int] = []
	biome_ids.resize(Chunk.SIZE * Chunk.SIZE)
	
	var landmark_ids: Array[int] = []
	landmark_ids.resize(Chunk.SIZE * Chunk.SIZE)

	# Pass 1: Gather raw heights and biome data dynamically
	for x in range(Chunk.SIZE):
		var global_x: int = chunk_offset_x + x
		for z in range(Chunk.SIZE):
			var global_z: int = chunk_offset_z + z
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(global_x, global_z, _terrain_noise)
			var idx: int = x + Chunk.SIZE * z
			raw_heights[idx] = profile.base_height
			biome_ids[idx] = profile.biome_id
			landmark_ids[idx] = profile.landmark_id

	# Pass 2: Terrain Smoothing Interpolation (Box Blur)
	# Converts sheer vertical walls into walkable slopes and ramps
	var smoothed_heights: Array[int] = []
	smoothed_heights.resize(Chunk.SIZE * Chunk.SIZE)
	for x in range(Chunk.SIZE):
		for z in range(Chunk.SIZE):
			var sum: int = 0
			var count: int = 0
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					# Clamp bounds safely
					var nx: int = clampi(x + dx, 0, Chunk.SIZE - 1)
					var nz: int = clampi(z + dz, 0, Chunk.SIZE - 1)
					sum += raw_heights[nx + Chunk.SIZE * nz]
					count += 1
			smoothed_heights[x + Chunk.SIZE * z] = int(round(float(sum) / float(count)))

	# Pass 3: Sculpt blocks polymorphically
	for x in range(Chunk.SIZE):
		var global_x: int = chunk_offset_x + x
		for z in range(Chunk.SIZE):
			var global_z: int = chunk_offset_z + z
			var idx: int = x + Chunk.SIZE * z
			var target_height: int = smoothed_heights[idx]
			var biome_id: int = biome_ids[idx]
			
			# Explicit static typing to prevent Variant inference errors
			var biome: IBiome = BiomeService.get_biome(biome_id)
			
			for y in range(Chunk.SIZE):
				var global_y: int = chunk_offset_y + y
				var block_type: BlockType.Type = BlockType.Type.AIR
				
				# Sculpt the terrain layers polymorphically
				if global_y <= target_height:
					block_type = biome.get_block_for_depth(global_y, target_height)
				else:
					# Aquatic Biomes Water levels
					if biome_id == 0 and global_y <= 5:
						block_type = BlockType.Type.WATER
					elif biome_id == 8 and global_y <= 4:
						block_type = BlockType.Type.WATER
						
					# --- CELESTIAL CLOUD ISLES GENERATION ---
					if (abs(global_x) + abs(global_z)) % 120 < 18 and global_y >= 12 and global_y <= 14:
						block_type = BlockType.Type.CLOUD
				
				chunk.set_block(x, y, z, block_type)

	# Pass 4: Spawn Organic Forests & Rare Landmarks
	for x in range(Chunk.SIZE):
		var global_x: int = chunk_offset_x + x
		for z in range(Chunk.SIZE):
			var global_z: int = chunk_offset_z + z
			var idx: int = x + Chunk.SIZE * z
			var ground_y: int = smoothed_heights[idx]
			
			# Ensure we only build on solid exposed ground
			if ground_y < 2 or ground_y > 11:
				continue
				
			var biome_id: int = biome_ids[idx]
			var scatter_hash: int = abs(global_x * 93856093 ^ global_z * 29349663)
			
			# 4A. Organic Forest Scatter
			if scatter_hash % 60 == 5:
				if biome_id == 2 or biome_id == 5: # Golden Bazaar / Redwood Forest
					_spawn_blueprint(chunk, x, z, ground_y, 1) # Oak Tree (ID 1)
			elif scatter_hash % 120 == 12:
				if biome_id == 5: # Redwood Forest specifically
					_spawn_blueprint(chunk, x, z, ground_y, 2) # Giant Redwood (ID 2)
			elif scatter_hash % 90 == 8:
				if biome_id == 1: # Warp Plateau (Mario)
					_spawn_blueprint(chunk, x, z, ground_y, 3) # Giant Mushroom (ID 3)
					
			# 4B. Rare Biome Landmarks
			var l_id: int = landmark_ids[idx]
			if l_id > 0 and LANDMARK_TO_BLUEPRINT.has(l_id):
				var blueprint_id: int = int(LANDMARK_TO_BLUEPRINT[l_id])
				_spawn_blueprint(chunk, x, z, ground_y, blueprint_id)

## Helper to fetch and execute blueprints from the dynamic registry safely
func _spawn_blueprint(chunk: Chunk, x: int, z: int, ground_y: int, blueprint_id: int) -> void:
	var blueprint: IStructureBlueprint = StructureLibrary.get_blueprint(blueprint_id)
	if blueprint != null:
		blueprint.build_structure(chunk, x, z, ground_y)
