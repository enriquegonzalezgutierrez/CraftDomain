# ==============================================================================
# Project: CraftDomain
# Description: Domain service responsible for procedurally generating terrain 
#              shaping Biomes, and spawning rare structured Landmarks.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/WorldGenerator.gd
# ==============================================================================
class_name WorldGenerator
extends RefCounted

var _terrain_noise: FastNoiseLite
var _biome_noise: FastNoiseLite

func _init(p_seed: int = 42) -> void:
	# 1. Primary Terrain Noise: Multi-Octave Fractal Brownian Motion (FBM)
	_terrain_noise = FastNoiseLite.new()
	_terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_terrain_noise.seed = p_seed
	_terrain_noise.frequency = 0.02
	_terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_terrain_noise.fractal_octaves = 4
	_terrain_noise.fractal_lacunarity = 2.0
	_terrain_noise.fractal_gain = 0.45
	
	# 2. Secondary Biome Noise: Low Frequency Simplex to classify terrains
	_biome_noise = FastNoiseLite.new()
	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_biome_noise.seed = p_seed + 1000
	_biome_noise.frequency = 0.005

## Generates and fills the internal voxel grid of a given Chunk.
func generate_chunk(chunk: Chunk) -> void:
	var chunk_offset_x := chunk.position.x * Chunk.SIZE
	var chunk_offset_y := chunk.position.y * Chunk.SIZE
	var chunk_offset_z := chunk.position.z * Chunk.SIZE

	# Store height limits locally for landmark evaluation pass
	var heights: Array[int] = []
	heights.resize(Chunk.SIZE * Chunk.SIZE)
	
	var landmark_types: Array[BiomeService.LandmarkType] = []
	landmark_types.resize(Chunk.SIZE * Chunk.SIZE)
	landmark_types.fill(BiomeService.LandmarkType.NONE)

	# Pass 1: Biome shaping and terrain blocks
	for x in range(Chunk.SIZE):
		var global_x := chunk_offset_x + x
		for z in range(Chunk.SIZE):
			var global_z := chunk_offset_z + z
			
			# Query the Biome Service to evaluate topography profile at this coordinate
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(
				global_x, 
				global_z, 
				_terrain_noise, 
				_biome_noise
			)
			
			var height_limit: int = profile.base_height
			heights[x + Chunk.SIZE * z] = height_limit
			landmark_types[x + Chunk.SIZE * z] = profile.landmark
			
			for y in range(Chunk.SIZE):
				var global_y := chunk_offset_y + y
				var block_type := BlockType.Type.AIR
				
				if global_y < height_limit - 2:
					block_type = BlockType.Type.STONE
				elif global_y < height_limit:
					block_type = BlockType.Type.DIRT
				elif global_y == height_limit:
					# Sand beach logic: If near ocean water height, paint as dirt sandbank
					if profile.biome == BiomeService.BiomeType.OCEAN and height_limit <= 4:
						block_type = BlockType.Type.DIRT
					else:
						block_type = BlockType.Type.GRASS
				
				chunk.set_block(x, y, z, block_type)

	# Pass 2: Procedural Structure Spawns
	for x in range(Chunk.SIZE):
		for z in range(Chunk.SIZE):
			var landmark: BiomeService.LandmarkType = landmark_types[x + Chunk.SIZE * z]
			if landmark == BiomeService.LandmarkType.NONE:
				continue
				
			var ground_y: int = heights[x + Chunk.SIZE * z]
			
			# Build landmarks safely inside vertical boundaries
			if ground_y > 1 and ground_y < 10:
				match landmark:
					BiomeService.LandmarkType.VILLAGE:
						# Spawn a detailed Village Cabin
						StructureLibrary.build_village_cabin(chunk, x, z, ground_y)
					BiomeService.LandmarkType.PORT:
						# Spawn Harbor Pier extending over water
						StructureLibrary.build_harbor_pier(chunk, x, z, ground_y)
					BiomeService.LandmarkType.CASTLE:
						# Spawn mountain peak stone Watchtower
						StructureLibrary.build_medieval_watchtower(chunk, x, z, ground_y)
