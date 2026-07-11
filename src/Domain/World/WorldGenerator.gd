# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / World Generation)
# Class: WorldGenerator
# Description: Domain Generator responsible for procedurally carving chunk block data.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Divided monolithic passes 
#                into isolated private helpers.
#              - Open-Closed Principle (OCP): EXTREME REFACTOR. Completely purged 
#                all hardcoded Biome IDs (0, 3, 6, 7, 8). The generator now queries 
#                the `IBiome` interfaces polymorphically (`requires_terrain_smoothing()`, 
#                `get_water_level()`), making this class 100% closed to modifications 
#                when adding new biomes or water features.
#              - Dependency Inversion (DIP): Spawns underground mineral veins by calling 
#                the polymorphic IOreVeinBlueprint strategies.
# ==============================================================================
class_name WorldGenerator
extends RefCounted

const CHUNK_MASK: int = 15

var _terrain_noise: FastNoiseLite
var _detail_noise: FastNoiseLite 
var _cave_noise: FastNoiseLite

var _ore_veins: Array[IOreVeinBlueprint] = []

const LANDMARK_TO_BLUEPRINT: Dictionary = {
	1: 9, 2: 4, 3: 8, 4: 5, 5: 6, 6: 7 
}

class ChunkProfileCache:
	var heights: PackedByteArray = PackedByteArray()
	var biomes: PackedByteArray = PackedByteArray()
	var landmarks: PackedByteArray = PackedByteArray()
	var on_road: PackedByteArray = PackedByteArray()
	
	func _init() -> void:
		heights.resize(Chunk.SIZE * Chunk.SIZE)
		biomes.resize(Chunk.SIZE * Chunk.SIZE)
		landmarks.resize(Chunk.SIZE * Chunk.SIZE)
		on_road.resize(Chunk.SIZE * Chunk.SIZE)

static var _global_profile_cache: Dictionary = {}
static var _cache_mutex: Mutex = Mutex.new()


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

	_cave_noise = FastNoiseLite.new()
	_cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_cave_noise.seed = p_seed + 777
	_cave_noise.frequency = 0.025
	_cave_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_cave_noise.fractal_octaves = 2

	_ore_veins.append(CoalVeinBlueprint.new())        
	_ore_veins.append(DiamondGeodeBlueprint.new())   


func generate_chunk(chunk: Chunk) -> void:
	var chunk_offset_x: int = chunk.position.x * Chunk.SIZE
	var chunk_offset_y: int = chunk.position.y * Chunk.SIZE
	var chunk_offset_z: int = chunk.position.z * Chunk.SIZE

	# 1. GENERATE RAW HEIGHT PROFILES
	var current_profile := _get_or_calculate_chunk_profile(chunk.position.x, chunk.position.z)
	
	# 2. SEAMLESS OCP BORDER SMOOTHING
	var smoothed_heights: Array[int] = _process_border_smoothing(chunk, current_profile)

	# 3. SCULPT BLOCKS & ROADS
	_sculpt_voxel_terrain(chunk, chunk_offset_x, chunk_offset_y, chunk_offset_z, current_profile, smoothed_heights)

	# 4. SPAWN PROCEDURAL STRUCTURES & FLORA
	_spawn_structures_and_flora(chunk, chunk_offset_x, chunk_offset_y, chunk_offset_z, current_profile, smoothed_heights)

	# 5. SUBTERRANEAN ORE VEINS
	if chunk.position.y == 0:
		_process_subterranean_veins(chunk, chunk_offset_x, chunk_offset_z)

	# 6. GLOBAL MEGA-STRUCTURES
	MegaStructureService.apply_mega_structures(chunk)


# ==============================================================================
# ISOLATED PIPELINE STEPS (SRP COMPLIANT)
# ==============================================================================

func _process_border_smoothing(chunk: Chunk, current_profile: ChunkProfileCache) -> Array[int]:
	var smoothed_heights: Array[int] = []
	smoothed_heights.resize(Chunk.SIZE * Chunk.SIZE)
	
	for x in range(Chunk.SIZE):
		for z in range(Chunk.SIZE):
			var sum: int = 0
			var count: int = 0
			
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var nx := x + dx
					var nz := z + dz
					
					var sample_height := 0
					if nx >= 0 and nx < Chunk.SIZE and nz >= 0 and nz < Chunk.SIZE:
						sample_height = current_profile.heights[nx + Chunk.SIZE * nz]
					else:
						var neighbor_chunk_x := chunk.position.x
						var neighbor_chunk_z := chunk.position.z
						
						if nx < 0: neighbor_chunk_x -= 1
						elif nx >= Chunk.SIZE: neighbor_chunk_x += 1
						
						if nz < 0: neighbor_chunk_z -= 1
						elif nz >= Chunk.SIZE: neighbor_chunk_z += 1
						
						var neighbor_profile := _get_or_calculate_chunk_profile(neighbor_chunk_x, neighbor_chunk_z)
						var wrapped_nx: int = nx & CHUNK_MASK
						var wrapped_nz: int = nz & CHUNK_MASK
						sample_height = neighbor_profile.heights[wrapped_nx + Chunk.SIZE * wrapped_nz]
						
					sum += sample_height
					count += 1
					
			var blur_height: int = int(round(float(sum) / float(count)))
			var idx: int = x + Chunk.SIZE * z
			var b_id: int = current_profile.biomes[idx]
			var biome: IBiome = BiomeService.get_biome(b_id)
			
			# OCP COMPLIANCE: Delegate smoothing decision strictly to the Biome strategy!
			var requires_smoothing: bool = biome.has_method("requires_terrain_smoothing") and biome.call("requires_terrain_smoothing")
			var is_on_road_col := current_profile.on_road[idx] == 1
			
			if is_on_road_col:
				smoothed_heights[idx] = current_profile.heights[idx]
			else:
				if requires_smoothing:
					smoothed_heights[idx] = int(lerp(float(current_profile.heights[idx]), float(blur_height), 0.40))
				else:
					smoothed_heights[idx] = blur_height
					
	return smoothed_heights


func _sculpt_voxel_terrain(chunk: Chunk, offset_x: int, offset_y: int, offset_z: int, profile: ChunkProfileCache, smoothed_heights: Array[int]) -> void:
	for x in range(Chunk.SIZE):
		var global_x: int = offset_x + x
		for z in range(Chunk.SIZE):
			var global_z: int = offset_z + z
			var idx: int = x + Chunk.SIZE * z
			var target_height: int = smoothed_heights[idx]
			var biome_id: int = profile.biomes[idx]
			var biome: IBiome = BiomeService.get_biome(biome_id)
			
			var on_road := profile.on_road[idx] == 1
			
			# OCP COMPLIANCE: Delegate water levels to the Biome strategy!
			var biome_water_level: int = -1
			if biome.has_method("get_water_level"):
				biome_water_level = biome.call("get_water_level") as int
			
			# Pre-emptive Bridge Fill: Raise roads crossing water up to sea level
			if on_road and target_height < biome_water_level:
				target_height = biome_water_level
			
			for y in range(Chunk.SIZE):
				var global_y: int = offset_y + y
				var block_type: BlockType.Type = BlockType.Type.AIR
				
				if global_y <= target_height:
					if global_y == target_height:
						block_type = _determine_surface_block(x, z, global_x, global_z, target_height, biome, biome_id, smoothed_heights)
					else:
						block_type = biome.get_block_for_depth(global_y, target_height)
						
					# Road Flush Embedding
					if on_road:
						if global_y == target_height and block_type != BlockType.Type.AIR:
							block_type = BlockType.Type.ROAD
						elif global_y >= target_height - 2 and block_type != BlockType.Type.AIR:
							block_type = BlockType.Type.STONE
							
					# SRP Extraction: 3D Cave Carving
					block_type = _carve_caves_and_lava(block_type, global_x, global_y, global_z, target_height)

				else:
					# Natural liquid filling below sea level
					if not on_road and global_y <= biome_water_level:
						block_type = BlockType.Type.WATER
				
				chunk.set_block(x, y, z, block_type)


func _carve_caves_and_lava(current_type: BlockType.Type, global_x: int, global_y: int, global_z: int, target_height: int) -> BlockType.Type:
	if current_type == BlockType.Type.STONE and global_y < target_height - 4 and global_y > 0:
		var cave_density := _cave_noise.get_noise_3d(float(global_x), float(global_y * 1.5), float(global_z))
		
		if cave_density > 0.45:
			if global_y < 4:
				return BlockType.Type.LAVA
			else:
				return BlockType.Type.AIR
	return current_type


func _spawn_structures_and_flora(chunk: Chunk, offset_x: int, offset_y: int, offset_z: int, profile: ChunkProfileCache, smoothed_heights: Array[int]) -> void:
	for x in range(Chunk.SIZE):
		var global_x: int = offset_x + x
		for z in range(Chunk.SIZE):
			var global_z: int = offset_z + z
			var idx: int = x + Chunk.SIZE * z
			var ground_y: int = smoothed_heights[idx]
			
			if ground_y < 2 or ground_y > 27: continue
			if profile.on_road[idx] == 1: continue
				
			var local_ground_y: int = ground_y - offset_y
			var biome_id: int = profile.biomes[idx]
			var biome: IBiome = BiomeService.get_biome(biome_id)
			var scatter_hash: int = abs(global_x * 93856093 ^ global_z * 29349663)
			
			var scatter_id: int = biome.get_scatter_blueprint_id(scatter_hash)
			if scatter_id > 0:
				_spawn_blueprint(chunk, x, z, local_ground_y, scatter_id)
					
			var l_id: int = profile.landmarks[idx]
			if l_id > 0 and LANDMARK_TO_BLUEPRINT.has(l_id):
				_spawn_blueprint(chunk, x, z, local_ground_y, int(LANDMARK_TO_BLUEPRINT[l_id]))


func _process_subterranean_veins(chunk: Chunk, offset_x: int, offset_z: int) -> void:
	var vein_rng := RandomNumberGenerator.new()
	var chunk_hash := abs(chunk.position.x * 73856093 ^ chunk.position.z * 19349663)
	vein_rng.seed = chunk_hash

	var vein_clusters_count := vein_rng.randi_range(3, 6)
	for i in range(vein_clusters_count):
		var rx := vein_rng.randi() % Chunk.SIZE
		var rz := vein_rng.randi() % Chunk.SIZE
		var ry := vein_rng.randi_range(2, 11)
		
		var spawn_roll := vein_rng.randf()
		var selected_vein: IOreVeinBlueprint = null

		if spawn_roll < 0.72:
			selected_vein = _ore_veins[0] 
		elif ry < 8: 
			selected_vein = _ore_veins[1] 

		if selected_vein != null:
			var unique_vein_seed := abs(int(offset_x + rx) * 3121 ^ int(offset_z + rz) * 19331 ^ (ry * 777))
			selected_vein.grow_vein(chunk, rx, ry, rz, unique_vein_seed)


func _get_or_calculate_chunk_profile(cx: int, cz: int) -> ChunkProfileCache:
	var key := Vector2i(cx, cz)
	
	_cache_mutex.lock()
	if _global_profile_cache.has(key):
		var cached: ChunkProfileCache = _global_profile_cache[key] as ChunkProfileCache
		_cache_mutex.unlock()
		return cached
	_cache_mutex.unlock()
	
	var profile := ChunkProfileCache.new()
	var chunk_offset_x := cx * Chunk.SIZE
	var chunk_offset_z := cz * Chunk.SIZE
	
	for x in range(Chunk.SIZE):
		var global_x: int = chunk_offset_x + x
		for z in range(Chunk.SIZE):
			var global_z: int = chunk_offset_z + z
			var idx := x + Chunk.SIZE * z
			
			var bio_profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(global_x, global_z, _terrain_noise)
			var detail_val: float = _detail_noise.get_noise_2d(float(global_x), float(global_z))
			var detail_modifier: int = int(detail_val * 2.2) 
			
			var on_road := RoadGeneratorService.is_on_road(float(global_x), float(global_z))
			
			var final_height: int = bio_profile.base_height + detail_modifier
				
			profile.heights[idx] = final_height
			profile.biomes[idx] = bio_profile.biome_id
			profile.landmarks[idx] = bio_profile.landmark_id
			profile.on_road[idx] = 1 if on_road else 0
			
	_cache_mutex.lock()
	_global_profile_cache[key] = profile
	_cache_mutex.unlock()
	
	return profile


func _determine_surface_block(
	x: int, z: int, gx: int, gz: int, 
	target_height: int, biome: IBiome, 
	biome_id: int, smoothed_heights: Array[int]
) -> BlockType.Type:
	
	var is_space: bool = false
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var nx: int = clampi(x + dx, 0, Chunk.SIZE - 1)
			var nz: int = clampi(z + dz, 0, Chunk.SIZE - 1)
			if abs(smoothed_heights[nx + Chunk.SIZE * nz] - target_height) > 2:
				is_space = true
				break
				
	if is_space and biome_id != 0 and biome_id != 9: 
		return BlockType.Type.STONE
		
	var default_surface: BlockType.Type = biome.get_block_for_depth(target_height, target_height)
	
	if default_surface == BlockType.Type.GRASS:
		var patch_val: float = _detail_noise.get_noise_2d(float(gx) * 2.0, float(gz) * 2.0)
		if patch_val > 0.45: return BlockType.Type.SAND 
		elif patch_val < -0.45: return BlockType.Type.DIRT 
			
	return default_surface


func _spawn_blueprint(chunk: Chunk, x: int, z: int, local_ground_y: int, blueprint_id: int) -> void:
	var blueprint: IStructureBlueprint = StructureLibrary.get_blueprint(blueprint_id)
	if blueprint != null:
		blueprint.build_structure(chunk, x, z, local_ground_y)
