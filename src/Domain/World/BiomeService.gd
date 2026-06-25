# ==============================================================================
# Project: CraftDomain
# Description: Domain Service acting as a Registry and Router for voxel biomes.
#              Provides dynamic registration (OCP compliant) and delegates
#              topography and styling calculations to concrete IBiome strategies,
#              closing this class to future modifications.
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
## This allows adding any number of new biomes without ever modifying this file (Strict OCP).
static func register_biome(biome: IBiome) -> void:
	if biome == null:
		return
		
	_biomes[biome.get_biome_id()] = biome
	print("[BiomeService] Dynamic Biome registered: [ID %d] %s" % [biome.get_biome_id(), biome.get_biome_name()])
	
	# Set the first registered biome as the safety fallback
	if _default_biome == null:
		_default_biome = biome

## Public API: Retrieves a registered biome strategy by its ID.
static func get_biome(biome_id: int) -> IBiome:
	if _biomes.has(biome_id):
		return _biomes[biome_id] as IBiome
	return _default_biome

## Evaluates any global coordinate and returns its mapped biome profile.
## Sector routing is calculated mathematically, delegating detailed properties to registered strategies.
static func evaluate_coordinate(global_x: int, global_z: int, terrain_noise: FastNoiseLite) -> BiomeProfile:
	var profile := BiomeProfile.new()
	
	# 1. Determine the geographical sector ID for this coordinate
	profile.biome_id = _calculate_sector_biome_id(global_x, global_z)
	
	# 2. Fetch the corresponding registered strategy
	var biome := get_biome(profile.biome_id)
	
	# 3. Delegate computations to the strategy (Strict OCP and SRP)
	var noise_val: float = terrain_noise.get_noise_2d(float(global_x), float(global_z))
	profile.base_height = biome.get_base_height(noise_val)
	
	# 4. Delegate deterministic landmark evaluation
	var spawn_hash: int = abs(global_x * 73856093 ^ global_z * 19349663)
	profile.landmark_id = biome.get_landmark_type(spawn_hash, profile.base_height)
	
	return profile

## Private helper mapping coordinates to sectors. 
## Centered region, North Polar Caps, and 8 radial cardinal slices.
static func _calculate_sector_biome_id(global_x: int, global_z: int) -> int:
	var gx := float(global_x)
	var gz := float(global_z)
	var distance: float = sqrt(gx * gx + gz * gz)
	var angle: float = atan2(gz, gx)
	
	if distance < 120.0:
		return 0 # BAY_OF_SAILS (Center)
	elif global_z < -450.0 and abs(global_x) < 200.0:
		return 4 # FROSTBITE_GLACIERS (Far North Cap)
	elif angle > -0.25 and angle < 0.25 and distance >= 120.0:
		return 2 # GOLDEN_BAZAAR (East Plain Corridor)
	elif angle >= 0.25 and angle < 1.25 and distance >= 120.0:
		return 5 # REDWOOD_FOREST (South-East Canopy)
	elif angle >= 1.25 or angle < -2.25:
		return 1 # WARP_PLATEAU (South Mario Steps)
	elif angle < -1.25 and angle >= -2.25:
		return 6 # RED_BADLANDS (South-West Terraces)
	elif angle >= -1.25 and angle < -0.25 and distance >= 200.0:
		return 7 # NEON_RUINS (North-East Obsidian Ruins)
	elif angle >= -1.25 and angle < -0.25:
		return 8 # SWAMP_OF_SIGHS (North-West Mud Valleys)
	else:
		return 3 # CRAGGY_MINES (Default North Mountains)
