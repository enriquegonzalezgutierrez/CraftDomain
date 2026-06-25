# ==============================================================================
# Project: CraftDomain
# Description: Domain Service responsible for procedurally carving chunk block 
#              data. Generates 10 distinct vertical voxel zones polimorphically
#              by delegating height, block layers, and landmark queries to
#              dynamic IBiome strategy classes, fulfilling strict OCP compliance.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/WorldGenerator.gd
# ==============================================================================
class_name WorldGenerator
extends RefCounted

var _terrain_noise: FastNoiseLite

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
	var chunk_offset_x := chunk.position.x * Chunk.SIZE
	var chunk_offset_y := chunk.position.y * Chunk.SIZE
	var chunk_offset_z := chunk.position.z * Chunk.SIZE

	# Heights and biome tracking arrays
	var heights: Array[int] = []
	heights.resize(Chunk.SIZE * Chunk.SIZE)
	
	var biome_ids: Array[int] = []
	biome_ids.resize(Chunk.SIZE * Chunk.SIZE)
	
	var landmark_ids: Array[int] = []
	landmark_ids.resize(Chunk.SIZE * Chunk.SIZE)

	# Pass 1: Biome shaping and terrain blocks
	for x in range(Chunk.SIZE):
		var global_x := chunk_offset_x + x
		for z in range(Chunk.SIZE):
			var global_z := chunk_offset_z + z
			
			# Evaluate coordinate profile dynamically
			var profile := BiomeService.evaluate_coordinate(global_x, global_z, _terrain_noise)
			var biome := BiomeService.get_biome(profile.biome_id)
			
			var idx := x + Chunk.SIZE * z
			heights[idx] = profile.base_height
			biome_ids[idx] = profile.biome_id
			landmark_ids[idx] = profile.landmark_id
			
			for y in range(Chunk.SIZE):
				var global_y := chunk_offset_y + y
				var block_type := BlockType.Type.AIR
				
				# Sculpt the terrain layers polimorphically by querying the concrete biome strategy (Strict OCP)
				if global_y <= profile.base_height:
					block_type = biome.get_block_for_depth(global_y, profile.base_height)
				else:
					# Sea/Water level logic for aquatic biomes (Bay of Sails [0] & Swamp [8])
					if profile.biome_id == 0 and global_y <= 5:
						block_type = BlockType.Type.WATER
					elif profile.biome_id == 8 and global_y <= 4:
						block_type = BlockType.Type.WATER
					
					# --- CELESTIAL CLOUD ISLES GENERATION ---
					if (abs(global_x) + abs(global_z)) % 120 < 18 and global_y >= 12 and global_y <= 14:
						block_type = BlockType.Type.CLOUD
				
				chunk.set_block(x, y, z, block_type)

	# Pass 2: Procedural Landmark Spawns
	for x in range(Chunk.SIZE):
		for z in range(Chunk.SIZE):
			var idx := x + Chunk.SIZE * z
			var landmark_id: int = landmark_ids[idx]
			if landmark_id == 0:
				continue
				
			var ground_y: int = heights[idx]
			
			# Build landmarks safely inside vertical bounds (avoiding top-chunk cuts)
			if ground_y > 1 and ground_y < 11:
				_spawn_landmark(chunk, x, z, ground_y, landmark_id)

## Instantiates procedural voxel blueprints for landmarks safely inside chunks based on ID mappings
func _spawn_landmark(chunk: Chunk, x: int, z: int, ground_y: int, landmark_id: int) -> void:
	match landmark_id:
		1:
			# Spawn a wooden dock pier (Bay of Sails)
			StructureLibrary.build_harbor_pier(chunk, x, z, ground_y)
		2:
			# Spawn a classic green vertical Warp Pipe structure (Warp Plateau)
			_build_warp_pipe(chunk, x, z, ground_y)
		3:
			# Spawn a rustic trading stall (Golden Bazaar)
			StructureLibrary.build_merchant_stall_with_fences(chunk, x, z, ground_y)
		4:
			# Spawn underground support beams (Craggy Mines)
			StructureLibrary.build_village_streetlight(chunk, x, z, ground_y)
		5:
			# Spawn a majestic ice spike tower (Frostbite Glaciers)
			StructureLibrary.build_medieval_watchtower(chunk, x, z, ground_y)
		6:
			# Spawn ancient ruins (Neon Ruins)
			StructureLibrary.build_village_cabin(chunk, x, z, ground_y)

## Carves a vertical hollow pipe structure using leaves as the green voxel texture
func _build_warp_pipe(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var pipe_height: int = 3
	for y in range(1, pipe_height + 1):
		var ly := ground_y + y
		# Build a hollow 2x2 ring of leaves (green plastic aesthetic)
		for px in range(2):
			for pz in range(2):
				var lx := start_x + px
				var lz := start_z + pz
				if chunk.is_within_bounds(lx, ly, lz):
					chunk.set_block(lx, ly, lz, BlockType.Type.LEAVES)
