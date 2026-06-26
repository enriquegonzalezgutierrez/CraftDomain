# ==============================================================================
# Project: CraftDomain
# Description: Domain Service acting as a Registry and Router for voxel biomes.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by isolating biome calculations.
#              FIXED: Corrected the Deterministic Starter Village Overwrite.
#              Only spawns the Village Cabin Landmark at the local center coordinate (8, 8)
#              of chunk [19, 0] to prevent spawning 256 overlapping cabins, which
#              glitched the chunk and suffocated the NPCs.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BiomeService.gd
# ==============================================================================
class_name BiomeService
extends RefCounted

## Dynamic registry mapping unique Biome IDs to their concrete IBiome strategies
static var _biomes: Dictionary = {}

## Fallback biome used when an unregistered ID is requested
static var _default_biome: IBiome

## Structure used to transport the compiled evaluation metrics across layers
class BiomeProfile:
	var biome_id: int
	var base_height: int
	var landmark_id: int

## Static registry API: Registers a concrete biome strategy at runtime.
static func register_biome(biome: IBiome) -> void:
	if biome == null:
		return
		
	_biomes[biome.get_biome_id()] = biome
	print("[BiomeService] Dynamic Biome registered: [ID %d] %s" % [biome.get_biome_id(), biome.get_biome_name()])
	
	if _default_biome == null:
		_default_biome = biome

## Public API: Retrieves a registered biome strategy by its ID.
static func get_biome(biome_id: int) -> IBiome:
	if _biomes.has(biome_id):
		return _biomes[biome_id] as IBiome
	return _default_biome

## Evaluates any global coordinate and returns its mapped biome profile.
static func evaluate_coordinate(global_x: int, global_z: int, terrain_noise: FastNoiseLite) -> BiomeProfile:
	var profile := BiomeProfile.new()
	
	# Translate global coordinates to chunk grid coordinates
	var chunk_x := int(floor(float(global_x) / 16.0))
	var chunk_z := int(floor(float(global_z) / 16.0))
	
	# --- DETERMINISTIC STARTER VILLAGE FORCING (RTX / SOLID Voxel Fix) ---
	# Forces chunk coordinates [19, 0] (which matches global X 304..319, Z 0..15) 
	# to always generate a flat Golden Bazaar village bazaar on every single Seed.
	if chunk_x == 19 and chunk_z == 0:
		profile.biome_id = 2 # Force Golden Bazaar Biome
		profile.base_height = 10 # Force flat ground height
		
		# FIXED: Only spawn the Village Cabin Landmark at the local center coordinate (8, 8)
		# to prevent spawning 256 overlapping cabins, which glitched and suffocated the NPCs!
		var local_x := global_x % 16
		var local_z := global_z % 16
		if local_x < 0: local_x += 16
		if local_z < 0: local_z += 16
		
		if local_x == 8 and local_z == 8:
			profile.landmark_id = 3 # Force single Market Cabin
		else:
			profile.landmark_id = 0
			
		return profile
	
	# 1. Determine the geographical sector ID for this coordinate
	profile.biome_id = _calculate_sector_biome_id(global_x, global_z)
	
	# 2. Fetch the corresponding registered strategy
	var biome := get_biome(profile.biome_id)
	
	# 3. Delegate computations to the strategy
	var noise_val: float = terrain_noise.get_noise_2d(float(global_x), float(global_z))
	profile.base_height = biome.get_base_height(noise_val)
	
	# 4. Delegate deterministic landmark evaluation
	var spawn_hash: int = abs(global_x * 73856093 ^ global_z * 19349663)
	profile.landmark_id = biome.get_landmark_type(spawn_hash, profile.base_height)
	
	return profile

static func _calculate_sector_biome_id(global_x: int, global_z: int) -> int:
	var gx := float(global_x)
	var gz := float(global_z)
	var distance: float = sqrt(gx * gx + gz * gz)
	var angle: float = atan2(gz, gx) 
	
	# Spawn Bay at center
	if distance < 130.0:
		return 0 # BAY_OF_SAILS (Spawn Ocean)
		
	# North Polar Ice Cap Core (Strict high altitude North cap)
	if global_z < -420.0 and abs(global_x) < 180.0:
		return 4 # FROSTBITE_GLACIERS (North Polar Cap)
		
	# 8 Symmetrical Cardinal Slices
	if angle >= -0.392 and angle < 0.392:
		return 2 # GOLDEN_BAZAAR (East Plain Corridor)
	elif angle >= 0.392 and angle < 1.178:
		return 5 # REDWOOD_FOREST (South-East Canopy)
	elif angle >= 1.178 and angle < 1.963:
		return 1 # WARP_PLATEAU (South Mario Steps)
	elif angle >= 1.963 and angle < 2.748:
		return 6 # RED_BADLANDS (South-West Terraces)
	elif angle >= 2.748 or angle < -2.748:
		return 8 # SWAMP_OF_SIGHS (West Mud Valleys)
	elif angle >= -2.748 and angle < -1.963:
		return 3 # CRAGGY_MINES (North-West Mountains)
	elif angle >= -1.963 and angle < -1.178:
		return 4 # FROSTBITE_GLACIERS (North Glacial shelves)
	else:
		return 7 # NEON_RUINS (North-East Obsidian Ruins)
