# ==============================================================================
# Project: CraftDomain
# Description: Domain Generator responsible for procedurally carving chunk block data.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Only handles world carving rules.
#              MEGA-STRUCTURES UPGRADE: Added Pass 5 to overlay global handcrafted 
#              fixed points of interest flawlessly over procedural terrain.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/WorldGenerator.gd
# ==============================================================================
class_name WorldGenerator
extends RefCounted

var _terrain_noise: FastNoiseLite
var _detail_noise: FastNoiseLite 

# Maps old Biome landmark IDs to new OCP Structure Blueprint IDs
const LANDMARK_TO_BLUEPRINT: Dictionary = {
	1: 9, # Port Dock -> Harbor Pier
	2: 4, # Warp Pipe -> Warp Pipe Blueprint
	3: 8, # Village Cabin -> Market Cabin
	4: 5, # Mine Pillar -> Mine Pillar
	5: 6, # Ice Temple -> Ice Temple
	6: 7  # Neon Pyramid -> Neon Pyramid
}

func _init(p_seed: int = 42) -> void:
	_terrain_noise = FastNoiseLite.new()
	_terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_terrain_noise.seed = p_seed
	_terrain_noise.frequency = 0.015
	_terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_terrain_noise.fractal_octaves = 4
	_terrain_noise.fractal_lacunarity = 2.0
	_terrain_noise.fractal_gain = 0.45

	_detail_noise = FastNoiseLite.new()
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.seed = p_seed + 101
	_detail_noise.frequency = 0.08
	_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail_noise.fractal_octaves = 2

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

	# PASS 1: Gather raw heights
	for x in range(Chunk.SIZE):
		var global_x: int = chunk_offset_x + x
		for z in range(Chunk.SIZE):
			var global_z: int = chunk_offset_z + z
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(global_x, global_z, _terrain_noise)
			var idx: int = x + Chunk.SIZE * z
			
			var detail_val: float = _detail_noise.get_noise_2d(float(global_x), float(global_z))
			var detail_modifier: int = int(detail_val * 2.2) 
			
			raw_heights[idx] = profile.base_height + detail_modifier
			biome_ids[idx] = profile.biome_id
			landmark_ids[idx] = profile.landmark_id

	# PASS 2: Selective Terrain Smoothing
	var smoothed_heights: Array[int] = []
	smoothed_heights.resize(Chunk.SIZE * Chunk.SIZE)
	for x in range(Chunk.SIZE):
		for z in range(Chunk.SIZE):
			var sum: int = 0
			var count: int = 0
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var nx: int = clampi(x + dx, 0, Chunk.SIZE - 1)
					var nz: int = clampi(z + dz, 0, Chunk.SIZE - 1)
					sum += raw_heights[nx + Chunk.SIZE * nz]
					count += 1
					
			var blur_height: int = int(round(float(sum) / float(count)))
			var idx: int = x + Chunk.SIZE * z
			var b_id: int = biome_ids[idx]
			
			if b_id == 3 or b_id == 6 or b_id == 7:
				smoothed_heights[idx] = int(lerp(float(raw_heights[idx]), float(blur_height), 0.40))
			else:
				smoothed_heights[idx] = blur_height

	# PASS 3: Sculpt blocks polymorphically
	for x in range(Chunk.SIZE):
		var global_x: int = chunk_offset_x + x
		for z in range(Chunk.SIZE):
			var global_z: int = chunk_offset_z + z
			var idx: int = x + Chunk.SIZE * z
			var target_height: int = smoothed_heights[idx]
			var biome_id: int = biome_ids[idx]
			var biome: IBiome = BiomeService.get_biome(biome_id)
			
			for y in range(Chunk.SIZE):
				var global_y: int = chunk_offset_y + y
				var block_type: BlockType.Type = BlockType.Type.AIR
				
				if global_y <= target_height:
					if global_y == target_height:
						block_type = _determine_surface_block(x, z, global_x, global_z, target_height, biome, biome_id, smoothed_heights)
					else:
						block_type = biome.get_block_for_depth(global_y, target_height)
				else:
					if biome_id == 0 and global_y <= 5:
						block_type = BlockType.Type.WATER
					elif biome_id == 8 and global_y <= 4:
						block_type = BlockType.Type.WATER
				
				chunk.set_block(x, y, z, block_type)

	# PASS 4: Spawn Organic Forests & Local Landmarks
	for x in range(Chunk.SIZE):
		var global_x: int = chunk_offset_x + x
		for z in range(Chunk.SIZE):
			var global_z: int = chunk_offset_z + z
			var idx: int = x + Chunk.SIZE * z
			var ground_y: int = smoothed_heights[idx]
			
			if ground_y < 2 or ground_y > 27:
				continue
				
			var local_ground_y: int = ground_y - chunk_offset_y
			
			var biome_id: int = biome_ids[idx]
			var biome: IBiome = BiomeService.get_biome(biome_id)
			var scatter_hash: int = abs(global_x * 93856093 ^ global_z * 29349663)
			
			var scatter_id: int = biome.get_scatter_blueprint_id(scatter_hash)
			if scatter_id > 0:
				_spawn_blueprint(chunk, x, z, local_ground_y, scatter_id)
					
			var l_id: int = landmark_ids[idx]
			if l_id > 0 and LANDMARK_TO_BLUEPRINT.has(l_id):
				var blueprint_id: int = int(LANDMARK_TO_BLUEPRINT[l_id])
				_spawn_blueprint(chunk, x, z, local_ground_y, blueprint_id)

	# =======================================================
	# PASS 5: OVERWRITE WITH GLOBAL MEGA-STRUCTURES
	# =======================================================
	MegaStructureService.apply_mega_structures(chunk)

func _determine_surface_block(
	x: int, z: int, gx: int, gz: int, 
	target_height: int, biome: IBiome, 
	biome_id: int, smoothed_heights: Array[int]
) -> BlockType.Type:
	
	var is_steep: bool = false
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var nx: int = clampi(x + dx, 0, Chunk.SIZE - 1)
			var nz: int = clampi(z + dz, 0, Chunk.SIZE - 1)
			if abs(smoothed_heights[nx + Chunk.SIZE * nz] - target_height) > 2:
				is_steep = true
				break
				
	if is_steep and biome_id != 0 and biome_id != 9: 
		return BlockType.Type.STONE
		
	var default_surface: BlockType.Type = biome.get_block_for_depth(target_height, target_height)
	
	if default_surface == BlockType.Type.GRASS:
		var patch_val: float = _detail_noise.get_noise_2d(float(gx) * 2.0, float(gz) * 2.0)
		if patch_val > 0.45:
			return BlockType.Type.SAND 
		elif patch_val < -0.45:
			return BlockType.Type.DIRT 
			
	return default_surface

func _spawn_blueprint(chunk: Chunk, x: int, z: int, local_ground_y: int, blueprint_id: int) -> void:
	var blueprint: IStructureBlueprint = StructureLibrary.get_blueprint(blueprint_id)
	if blueprint != null:
		blueprint.build_structure(chunk, x, z, local_ground_y)
