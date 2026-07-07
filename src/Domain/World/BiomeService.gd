# ==============================================================================
# Project: CraftDomain
# Description: Domain Service acting as a Registry and Coordinator for voxel biomes.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates coordinate 
#   evaluations and biome registrations.
# - Open-Closed Principle (OCP): Dynamic territory routing. The service no longer 
#   contains hardcoded coordinate divisions, delegating boundary checks polimorphically 
#   to the registered `IBiome` strategy classes.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BiomeService.gd
# ==============================================================================
class_name BiomeService
extends RefCounted

## Dynamic registry mapping unique Biome IDs to their concrete IBiome strategies.
static var _biomes: Dictionary = {}

## Fallback biome used when an unregistered ID is requested.
static var _default_biome: IBiome


## Struct used to transport the compiled evaluation metrics across system layers.
class BiomeProfile:
	var biome_id: int
	var base_height: int
	var landmark_id: int


## Startup Initializer: Instantiates and registers the default set of 
## geographical biomes, keeping Bootstrap.gd clean (SRP/OCP compliant).
static func initialize_biomes() -> void:
	print("[BiomeService] Initializing and registering geographical biomes...")
	_biomes.clear()
	
	register_biome(BayOfSailsBiome.new())
	register_biome(WarpPlateauBiome.new())
	register_biome(GoldenBazaarBiome.new())
	register_biome(CraggyMinesBiome.new())
	register_biome(FrostbiteGlaciersBiome.new())
	register_biome(RedwoodForestBiome.new())
	register_biome(RedBadlandsBiome.new())
	register_biome(NeonRuinsBiome.new())
	register_biome(SwampOfSighsBiome.new())
	register_biome(CloudKingdomBiome.new())
	
	print("[BiomeService] Initialization complete. Registered biomes count: ", _biomes.size())


## Static registry API: Registers a concrete biome strategy at runtime.
static func register_biome(biome: IBiome) -> void:
	if biome == null:
		return
		
	_biomes[biome.get_biome_id()] = biome
	
	if _default_biome == null:
		_default_biome = biome


## Public API: Retrieves a registered biome strategy by its unique ID.
static func get_biome(biome_id: int) -> IBiome:
	if _biomes.has(biome_id):
		return _biomes[biome_id] as IBiome
	return _default_biome


## Evaluates any global coordinate and returns its mapped biome profile.
static func evaluate_coordinate(global_x: int, global_z: int, terrain_noise: FastNoiseLite) -> BiomeProfile:
	var profile := BiomeProfile.new()
	
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


## Calculates the deterministic biome sector ID polimorphically (OCP Compliant).
static func _calculate_sector_biome_id(global_x: int, global_z: int) -> int:
	var gx := float(global_x)
	var gz := float(global_z)
	var pos_flat := Vector2(gx, gz)
	var distance: float = pos_flat.length()
	
	# Spawn Bay at center has priority over all other biomes (ID 0)
	if distance < 130.0:
		return 0 # BAY_OF_SAILS
		
	var angle: float = atan2(gz, gx) 
	
	# Symmetrical Polimorphic Query:
	# Iterate through registered biomes, letting them decide if they own this coordinate.
	# FIX: Explicit static typing on loop biome ID keys iterator
	for b_id: int in _biomes.keys():
		if b_id == 0:
			continue # Skip spawn bay which was handled
			
		var biome: IBiome = _biomes[b_id] as IBiome
		if is_instance_valid(biome) and biome.has_method("is_coordinate_inside"):
			if biome.call("is_coordinate_inside", pos_flat, distance, angle):
				return b_id
				
	return _default_biome.get_biome_id()
