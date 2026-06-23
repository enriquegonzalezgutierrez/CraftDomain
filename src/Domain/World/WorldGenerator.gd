# ==============================================================================
# Project: CraftDomain
# Description: Domain service responsible for procedurally generating terrain 
#              and scattering structures (village houses) inside chunks.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/WorldGenerator.gd
# ==============================================================================
class_name WorldGenerator
extends RefCounted

var _noise: FastNoiseLite

func _init(p_seed: int = 42) -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.seed = p_seed
	_noise.frequency = 0.03

## Generates and fills the internal voxel grid of a given Chunk.
func generate_chunk(chunk: Chunk) -> void:
	var chunk_offset_x := chunk.position.x * Chunk.SIZE
	var chunk_offset_y := chunk.position.y * Chunk.SIZE
	var chunk_offset_z := chunk.position.z * Chunk.SIZE

	# Store heights to find flat ground for houses later
	var heights: Array[int] = []
	heights.resize(Chunk.SIZE * Chunk.SIZE)

	# Pass 1: Heightmap & Terrain layers
	for x in range(Chunk.SIZE):
		var global_x := chunk_offset_x + x
		for z in range(Chunk.SIZE):
			var global_z := chunk_offset_z + z
			
			var noise_val := _noise.get_noise_2d(float(global_x), float(global_z))
			var height_limit := int(remap(noise_val, -1.0, 1.0, 2.0, 10.0))
			heights[x + Chunk.SIZE * z] = height_limit
			
			for y in range(Chunk.SIZE):
				var global_y := chunk_offset_y + y
				var block_type := BlockType.Type.AIR
				
				if global_y < height_limit - 2:
					block_type = BlockType.Type.STONE
				elif global_y < height_limit:
					block_type = BlockType.Type.DIRT
				elif global_y == height_limit:
					block_type = BlockType.Type.GRASS
				
				chunk.set_block(x, y, z, block_type)

	# Pass 2: Procedural Village House Placement
	# Deterministically spawn a village house in specific chunks (e.g., every 3rd chunk grid interval)
	var should_spawn_house: bool = (abs(chunk.position.x) + abs(chunk.position.z)) % 3 == 2 and chunk.position.y == 0
	
	if should_spawn_house:
		# Place the house offset in the center of the chunk (X=5, Z=5)
		var start_x: int = 5
		var start_z: int = 5
		var ground_height: int = heights[start_x + Chunk.SIZE * start_z]
		
		# Verify ground height fits safely within our vertical chunk slice
		if ground_height > 1 and ground_height < 11:
			_build_local_village_house(chunk, start_x, start_z, ground_height)

func _build_local_village_house(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var house_width: int = 5
	var house_depth: int = 5
	var house_height: int = 4
	
	# 1. Foundation (Stone flooring layers)
	for x in range(house_width):
		var lx := start_x + x
		for z in range(house_depth):
			var lz := start_z + z
			# Replace blocks under foundation to prevent floating on sloped hillsides
			for fill_y in range(ground_y - 2, ground_y + 1):
				chunk.set_block(lx, fill_y, lz, BlockType.Type.STONE)

	# 2. Hollow Wood Walls
	for y in range(1, house_height):
		var ly := ground_y + y
		for x in range(house_width):
			var lx := start_x + x
			for z in range(house_depth):
				var lz := start_z + z
				
				var is_edge: bool = (x == 0 or x == house_width - 1 or z == 0 or z == house_depth - 1)
				if is_edge:
					# Doorway opening at the front center (x=2, z=0)
					var is_door: bool = (x == 2 and z == 0 and (y == 1 or y == 2))
					if is_door:
						chunk.set_block(lx, ly, lz, BlockType.Type.AIR)
					else:
						chunk.set_block(lx, ly, lz, BlockType.Type.WOOD)
				else:
					chunk.set_block(lx, ly, lz, BlockType.Type.AIR)

	# 3. Overhanging Shrubbery Roof (Leaves)
	var roof_y := ground_y + house_height
	for x in range(-1, house_width + 1):
		var lx := start_x + x
		for z in range(-1, house_depth + 1):
			var lz := start_z + z
			if chunk.is_within_bounds(lx, roof_y, lz):
				chunk.set_block(lx, roof_y, lz, BlockType.Type.LEAVES)
