# ==============================================================================
# Pathfile: res://src/Domain/World/BiomeService.gd
# Description: Pure Domain Service acting as a Registry and Coordinator for voxel biomes.
#              Centralizes biome evaluation and coordinate-sensing mechanics (SRP / DRY).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
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
	
	func _init() -> void:
		biome_id = 2
		base_height = 0
		landmark_id = 0


## Startup Initializer: Instantiates and registers the default set of biomes
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
	profile.biome_id = _calculate_sector_biome_id(global_x, global_z)
	
	var biome := get_biome(profile.biome_id)
	var noise_val: float = terrain_noise.get_noise_2d(float(global_x), float(global_z))
	profile.base_height = biome.get_base_height(noise_val)
	
	var spawn_hash: int = abs(global_x * 73856093 ^ global_z * 19349663)
	profile.landmark_id = biome.get_landmark_type(spawn_hash, profile.base_height)
	
	return profile


# ==============================================================================
# SENSORY DRY COMPLIANCE API (SOLID SRP)
# Centralizes geographical coordinates-sensing from any spatial Node3D.
# ==============================================================================

## Symmetrical static checker: Evaluates world generator noise to resolve Biome IDs
static func get_biome_id_at_position(global_pos: Vector3, world_node: Node) -> int:
	if is_instance_valid(world_node) and "generator" in world_node:
		var generator_node := world_node.get("generator") as WorldGenerator
		if generator_node != null:
			var terrain_noise := generator_node.get("_terrain_noise") as FastNoiseLite
			if terrain_noise != null:
				var profile := evaluate_coordinate(int(round(global_pos.x)), int(round(global_pos.z)), terrain_noise)
				return profile.biome_id
	return 2 # Default Golden Bazaar plains ID


## Calculates the deterministic biome sector ID polimorphically (OCP Compliant).
static func _calculate_sector_biome_id(global_x: int, global_z: int) -> int:
	var gx := float(global_x)
	var gz := float(global_z)
	var pos_flat := Vector2(gx, gz)
	var distance: float = pos_flat.length()
	
	if distance < 130.0:
		return 0 # BAY_OF_SAILS
		
	var angle: float = atan2(gz, gx) 
	
	for b_id: int in _biomes.keys():
		if b_id == 0:
			continue 
			
		var biome: IBiome = _biomes[b_id] as IBiome
		if is_instance_valid(biome) and biome.has_method("is_coordinate_inside"):
			if biome.call("is_coordinate_inside", pos_flat, distance, angle):
				return b_id
				
	return _default_biome.get_biome_id()
