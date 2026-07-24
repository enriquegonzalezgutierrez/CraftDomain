# ==============================================================================
# Pathfile: res://src/Domain/World/BiomeService.gd
# Description: Pure Domain Service acting as a Registry and Coordinator for voxel biomes.
#              Centralizes biome evaluation and coordinate-sensing mechanics (SRP / DRY).
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
	
	func _init() -> void:
		biome_id = 2
		base_height = 0
		landmark_id = 0


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
	register_biome(EmeraldZoneBiome.new())


static func register_biome(biome: IBiome) -> void:
	if biome == null: return
		
	_biomes[biome.get_biome_id()] = biome
	
	if _default_biome == null or biome.get_biome_id() == 2:
		_default_biome = biome


static func get_biome(biome_id: int) -> IBiome:
	if _biomes.has(biome_id):
		return _biomes[biome_id] as IBiome
	return _default_biome


static func evaluate_coordinate(global_x: int, global_z: int, terrain_noise: FastNoiseLite) -> BiomeProfile:
	var profile: BiomeProfile = BiomeProfile.new()
	profile.biome_id = _calculate_sector_biome_id(global_x, global_z)
	
	var biome: IBiome = get_biome(profile.biome_id)
	var noise_val: float = terrain_noise.get_noise_2d(float(global_x), float(global_z))
	profile.base_height = biome.get_base_height(noise_val)
	
	var spawn_hash: int = abs(global_x * 73856093 ^ global_z * 19349663)
	profile.landmark_id = biome.get_landmark_type(spawn_hash, profile.base_height)
	
	return profile


static func get_biome_id_at_position(global_pos: Vector3, world_node: Node) -> int:
	if is_instance_valid(world_node) and "generator" in world_node:
		var generator_node := world_node.get("generator") as WorldGenerator
		if generator_node != null:
			var terrain_noise := generator_node.get("_terrain_noise") as FastNoiseLite
			if terrain_noise != null:
				var profile := evaluate_coordinate(int(round(global_pos.x)), int(round(global_pos.z)), terrain_noise)
				return profile.biome_id
	return 2 


static func _calculate_sector_biome_id(global_x: int, global_z: int) -> int:
	var pos_flat := Vector2(float(global_x), float(global_z))
	var distance: float = pos_flat.length()
	
	if distance < 130.0:
		return 0 # BAY_OF_SAILS (Ocean spawn core)
		
	var angle: float = atan2(float(global_z), float(global_x)) 
	return _evaluate_sector_boundary_loop(pos_flat, distance, angle)


static func _evaluate_sector_boundary_loop(_pos_flat: Vector2, _distance: float, angle: float) -> int:
	# 1. NORTH SECTOR (Warp Plateau, ID 1): [75° to 105°]
	if angle >= 1.31 and angle < 1.83: return 1
	
	# 2. NORTH-WEST SECTOR (Cloud Kingdom, ID 9): [120° to 150°]
	if angle >= 2.10 and angle < 2.62: return 9
	
	# 3. WEST SECTOR (Swamp of Sighs, ID 8): [165° to -165°]
	if angle >= 2.88 or angle < -2.88: return 8
	
	# 4. SOUTH-WEST SECTOR (Craggy Mines, ID 3): [-150° to -120°]
	if angle >= -2.62 and angle < -2.10: return 3
	
	# 5. SOUTH SECTOR (Frostbite Glaciers, ID 4): [-105° to -75°]
	if angle >= -1.83 and angle < -1.31: return 4
	
	# 6. SOUTH-EAST SECTOR (Neon Ruins, ID 7): [-60° to -30°]
	if angle >= -1.05 and angle < -0.52: return 7
	
	# 7. EAST SECTOR (Red Badlands, ID 6): [-15° to 15°]
	if angle >= -0.26 and angle < 0.26: return 6
	
	# 8. NORTH-EAST SECTOR (Emerald Zone, ID 10 & Redwood Forest, ID 5)
	if angle >= 0.70 and angle < 1.05: return 10
	if angle >= 0.26 and angle < 0.70: return 5
	
	return _default_biome.get_biome_id()
