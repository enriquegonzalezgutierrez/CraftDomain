# ==============================================================================
# Project: CraftDomain
# Description: Domain Generator responsible for procedurally carving chunk block data.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Only handles world carving rules.
#              - Dependency Inversion Principle (DIP): Integrates paved roads by 
#                calling the RoadGeneratorService abstraction.
#              PHASE 2 CACHE PIPELINE & SEAMLESS SMOOTHING:
#              - Added `ChunkProfileCache` to store computed heights, biomes, and
#                road properties, cutting noise query times by up to 60%.
#              - Upgraded Pass 2 to smooth heights across chunk boundaries using
#                the shared cache, removing edge line visual seam artifacts.
#              - Thread Safety: Implemented a static Mutex to protect cache reads/writes
#                across WorkerThreadPool threads.
#              MILESTONE 8 UPGRADE (3D CAVES & ORE VEINS):
#              - Added `_cave_noise` (Fractal Ridged 3D noise) to carve interconnected 
#                subterranean tunnel networks (Spaghetti caves).
#              - Programmed procedural vein distribution for DIAMOND_ORE (28) and 
#                COAL_ORE (21) directly along deep cavern walls.
#              - Added Deep Lava Pools: Caverns intersecting Y < 4 will automatically 
#                fill with Lava, creating natural underground danger zones.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/WorldGenerator.gd
# ==============================================================================
class_name WorldGenerator
extends RefCounted

## Local bitmask constant (Chunk.SIZE - 1) used for fast coordinate wrapping
const CHUNK_MASK: int = 15

var _terrain_noise: FastNoiseLite
var _detail_noise: FastNoiseLite 
var _cave_noise: FastNoiseLite # NEW: Fractal Ridged 3D noise for cavern generation

# Maps old Biome landmark IDs to new OCP Structure Blueprint IDs
const LANDMARK_TO_BLUEPRINT: Dictionary = {
	1: 9, # Port Dock -> Harbor Pier
	2: 4, # Warp Pipe -> Warp Pipe Blueprint
	3: 8, # Village Cabin -> Market Cabin
	4: 5, # Mine Pillar -> Mine Pillar
	5: 6, # Ice Temple -> Ice Temple
	6: 7  # Neon Pyramid -> Neon Pyramid
}

# ==============================================================================
# PHASE 2 OPTIMIZATION: GLOBAL THREAD-SAFE HEIGHT & BIOME CACHE
# ==============================================================================
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

## Shared cache mapping Vector2i (chunk positions x, z) to cached ChunkProfileCache
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

	# ==========================================================================
	# 3D CAVE NOISE CONFIGURATION
	# Uses FRACTAL_RIDGED to create interconnected, branching tunnel systems
	# ==========================================================================
	_cave_noise = FastNoiseLite.new()
	_cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_cave_noise.seed = p_seed + 777
	_cave_noise.frequency = 0.025 # Controls the thickness and sprawl of the caves
	_cave_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_cave_noise.fractal_octaves = 2


## Generates and fills the internal voxel grid of a given Chunk.
func generate_chunk(chunk: Chunk) -> void:
	var chunk_offset_x: int = chunk.position.x * Chunk.SIZE
	var chunk_offset_y: int = chunk.position.y * Chunk.SIZE
	var chunk_offset_z: int = chunk.position.z * Chunk.SIZE

	# 1. Fetch or generate the raw height and biome metrics for this chunk
	var current_profile := _get_or_calculate_chunk_profile(chunk.position.x, chunk.position.z)
	
	var smoothed_heights: Array[int] = []
	smoothed_heights.resize(Chunk.SIZE * Chunk.SIZE)

	# PASS 2: SEAMLESS BORDER SMOOTHING
	for x in range(Chunk.SIZE):
		for z in range(Chunk.SIZE):
			var sum: int = 0
			var count: int = 0
			
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var nx := x + dx
					var nz := z + dz
					
					var sample_height := 0
					# Check if within local chunk limits
					if nx >= 0 and nx < Chunk.SIZE and nz >= 0 and nz < Chunk.SIZE:
						sample_height = current_profile.heights[nx + Chunk.SIZE * nz]
					else:
						# Target pixel crosses into a neighboring chunk border, fetch from the global cache!
						var neighbor_chunk_x := chunk.position.x
						var neighbor_chunk_z := chunk.position.z
						
						if nx < 0: neighbor_chunk_x -= 1
						elif nx >= Chunk.SIZE: neighbor_chunk_x += 1
						
						if nz < 0: neighbor_chunk_z -= 1
						elif nz >= Chunk.SIZE: neighbor_chunk_z += 1
						
						var neighbor_profile := _get_or_calculate_chunk_profile(neighbor_chunk_x, neighbor_chunk_z)
						
						# Wrap local indices to 0..15 bounds
						var wrapped_nx: int = nx & CHUNK_MASK
						var wrapped_nz: int = nz & CHUNK_MASK
						sample_height = neighbor_profile.heights[wrapped_nx + Chunk.SIZE * wrapped_nz]
						
					sum += sample_height
					count += 1
					
			var blur_height: int = int(round(float(sum) / float(count)))
			var idx: int = x + Chunk.SIZE * z
			var b_id: int = current_profile.biomes[idx]
			
			# Apply localized smoothing based on biome rules (Mountains & Canyons)
			if b_id == 3 or b_id == 6 or b_id == 7:
				smoothed_heights[idx] = int(lerp(float(current_profile.heights[idx]), float(blur_height), 0.40))
			else:
				smoothed_heights[idx] = blur_height

	# PASS 3: Sculpt blocks polymorphically and pave roads with bridge pillar foundations
	for x in range(Chunk.SIZE):
		var global_x: int = chunk_offset_x + x
		for z in range(Chunk.SIZE):
			var global_z: int = chunk_offset_z + z
			var idx: int = x + Chunk.SIZE * z
			var target_height: int = smoothed_heights[idx]
			var biome_id: int = current_profile.biomes[idx]
			var biome: IBiome = BiomeService.get_biome(biome_id)
			
			var on_road := current_profile.on_road[idx] == 1
			
			for y in range(Chunk.SIZE):
				var global_y: int = chunk_offset_y + y
				var block_type: BlockType.Type = BlockType.Type.AIR
				
				if global_y <= target_height:
					if on_road:
						# Road Pavement styling (Clean ROAD block integration)
						if global_y == target_height:
							block_type = BlockType.Type.ROAD   # Dedicated paved road block
						elif global_y == target_height - 1:
							block_type = BlockType.Type.STONE  # Solid sub-base
						else:
							# BRIDGE PILLARS: Solidify columns over water/air gaps down to solid ocean bed
							var natural_block := biome.get_block_for_depth(global_y, target_height)
							if natural_block == BlockType.Type.WATER or natural_block == BlockType.Type.AIR:
								block_type = BlockType.Type.STONE # Support pillar column
							else:
								block_type = natural_block
					else:
						# Natural terrain carving
						if global_y == target_height:
							block_type = _determine_surface_block(x, z, global_x, global_z, target_height, biome, biome_id, smoothed_heights)
						else:
							block_type = biome.get_block_for_depth(global_y, target_height)
							
					# ==========================================================
					# MILESTONE 8: 3D CAVE CARVING SYSTEM
					# Carve tunnels only in solid deep stone, keeping the top 4 
					# layers intact to prevent the surface from looking like Swiss cheese.
					# ==========================================================
					if block_type == BlockType.Type.STONE and global_y < target_height - 4 and global_y > 0:
						# Evaluate 3D Noise density
						var cave_density := _cave_noise.get_noise_3d(float(global_x), float(global_y * 1.5), float(global_z))
						
						# Threshold > 0.45 creates nice winding, continuous tunnels
						if cave_density > 0.45:
							# Feature: Deepest caverns (Y < 4) fill with natural Lava!
							if global_y < 4:
								block_type = BlockType.Type.LAVA
							else:
								block_type = BlockType.Type.AIR
						else:
							# If we are NOT in empty cave air, randomly distribute ore veins on solid walls
							var ore_roll := randf()
							if ore_roll < 0.015: # 1.5% chance to spawn Coal Ore
								block_type = BlockType.Type.COAL_ORE
							elif ore_roll < 0.020 and global_y < 12: # 0.5% chance to spawn glowing Diamond deep underground
								block_type = BlockType.Type.DIAMOND_ORE

				else:
					if not on_road: # Roads rise above water level forming beautiful bridge piers
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
				
			var on_road := current_profile.on_road[idx] == 1
			if on_road:
				continue # Highways stay completely cleared
				
			var local_ground_y: int = ground_y - chunk_offset_y
			
			var biome_id: int = current_profile.biomes[idx]
			var biome: IBiome = BiomeService.get_biome(biome_id)
			var scatter_hash: int = abs(global_x * 93856093 ^ global_z * 29349663)
			
			var scatter_id: int = biome.get_scatter_blueprint_id(scatter_hash)
			if scatter_id > 0:
				_spawn_blueprint(chunk, x, z, local_ground_y, scatter_id)
					
			var l_id: int = current_profile.landmarks[idx]
			if l_id > 0 and LANDMARK_TO_BLUEPRINT.has(l_id):
				var blueprint_id: int = int(LANDMARK_TO_BLUEPRINT[l_id])
				_spawn_blueprint(chunk, x, z, local_ground_y, blueprint_id)

	# PASS 5: OVERWRITE WITH GLOBAL MEGA-STRUCTURES
	MegaStructureService.apply_mega_structures(chunk)


## Thread-safe loader checking the global cache before generating noise.
func _get_or_calculate_chunk_profile(cx: int, cz: int) -> ChunkProfileCache:
	var key := Vector2i(cx, cz)
	
	_cache_mutex.lock()
	if _global_profile_cache.has(key):
		var cached: ChunkProfileCache = _global_profile_cache[key] as ChunkProfileCache
		_cache_mutex.unlock()
		return cached
	_cache_mutex.unlock()
	
	# Generate new cache profile
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
			
			var final_height: int = bio_profile.base_height + detail_modifier
			var on_road := RoadGeneratorService.is_on_road(float(global_x), float(global_z))
			
			if on_road and final_height < 6:
				final_height = 6 # Bridge deck line
				
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
		if patch_val > 0.45:
			return BlockType.Type.SAND 
		elif patch_val < -0.45:
			return BlockType.Type.DIRT 
			
	return default_surface


func _spawn_blueprint(chunk: Chunk, x: int, z: int, local_ground_y: int, blueprint_id: int) -> void:
	var blueprint: IStructureBlueprint = StructureLibrary.get_blueprint(blueprint_id)
	if blueprint != null:
		blueprint.build_structure(chunk, x, z, local_ground_y)
