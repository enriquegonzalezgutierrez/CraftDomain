# ==============================================================================
# Pathfile: res://src/Domain/World/BiomeService.gd
# Description: Domain Service acting as a Registry and Coordinator for voxel biomes.
#              Decomposed into clear, isolated territory checking methods (SRP / OCP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name BiomeService
extends RefCounted

static var _biomes: Dictionary = {}
static var _default_biome: IBiome

class BiomeProfile:
	var biome_id: int
	var base_height: int
	var landmark_id: int


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
	
	print("[BiomeService] Initialization complete. Registered biomes count: ", _biomes.size())


static func register_biome(biome: IBiome) -> void:
	if biome == null: return
	_biomes[biome.get_biome_id()] = biome
	if _default_biome == null:
		_default_biome = biome


## Public Reader API: Queries any biome strategy by its ID
static func get_biome(biome_id: int) -> IBiome:
	if _biomes.has(biome_id):
		return _biomes[biome_id] as IBiome
	return _default_biome


## Evaluates any global coordinate and returns its mapped biome profile
static func evaluate_coordinate(global_x: int, global_z: int, terrain_noise: FastNoiseLite) -> BiomeProfile:
	var profile := BiomeProfile.new()
	profile.biome_id = _calculate_sector_biome_id(global_x, global_z)
	
	var biome := get_biome(profile.biome_id)
	var noise_val: float = terrain_noise.get_noise_2d(float(global_x), float(global_z))
	profile.base_height = biome.get_base_height(noise_val)
	
	var spawn_hash: int = abs(global_x * 73856093 ^ global_z * 19349663)
	profile.landmark_id = biome.get_landmark_type(spawn_hash, profile.base_height)
	return profile


static func _calculate_sector_biome_id(global_x: int, global_z: int) -> int:
	var pos_flat := Vector2(float(global_x), float(global_z))
	var distance := pos_flat.length()
	
	# Spawn Ocean (Bay of Sails) has absolute center priority
	if distance < 130.0:
		return 0 
		
	var angle := atan2(float(global_z), float(global_x))
	return _query_polymorphic_biome_territories(pos_flat, distance, angle)


static func _query_polymorphic_biome_territories(pos_flat: Vector2, distance: float, angle_rad: float) -> int:
	# Symmetrical Polimorphic Query:
	# Let each registered biome decide if it owns this coordinate.
	for b_id: int in _biomes.keys():
		if b_id == 0:
			continue # Skip spawn bay
			
		var biome := _biomes[b_id] as IBiome
		if is_instance_valid(biome) and biome.has_method("is_coordinate_inside"):
			if biome.call("is_coordinate_inside", pos_flat, distance, angle_rad):
				return b_id
				
	return _default_biome.get_biome_id()
