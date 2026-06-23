# ==============================================================================
# Project: CraftDomain
# Description: Domain service responsible for procedurally generating terrain 
#              and distributing blocks inside chunks.
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

	for x in range(Chunk.SIZE):
		var global_x := chunk_offset_x + x
		for z in range(Chunk.SIZE):
			var global_z := chunk_offset_z + z
			
			# Sample 2D simplex noise and remap to local coordinates [2..14]
			# ensuring we stay safely within a single chunk height limit for now.
			var noise_val := _noise.get_noise_2d(float(global_x), float(global_z))
			var height_limit := int(remap(noise_val, -1.0, 1.0, 2.0, 12.0))
			
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
