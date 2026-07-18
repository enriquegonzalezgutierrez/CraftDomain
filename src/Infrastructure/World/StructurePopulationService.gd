# ==============================================================================
# Pathfile: res://src/Infrastructure/World/StructurePopulationService.gd
# Description: Infrastructure Service managing the roster, coordinates, and 
#              unification of NPC and prop spawns inside handcrafted Landmarks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates Landmark 
#   population rosters, completely isolating spawning from voxel sculpting.
# - Open-Closed Principle (OCP): Closed to modifications; open to new landmark
#   populations by adding registration methods without altering voxel blueprints.
# - Method Size Limits (Rule 4.2): Decomposed into modular, typesafe helper 
#   initializers kept strictly < 20 lines of code.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name StructurePopulationService
extends RefCounted

## Pure Data Carrier (Value Object) representing a verified spawning coordinate
class PopulationPoint:
	var is_prop: bool
	var spawn_id: int
	var global_pos: Vector3
	
	func _init(p_is_prop: bool, p_id: int, p_pos: Vector3) -> void:
		is_prop = p_is_prop
		spawn_id = p_id
		global_pos = p_pos

# In-memory index database: Vector3i (chunk_pos) -> Array[PopulationPoint]
static var _population_registry: Dictionary = {}
static var _initialized: bool = false


## Public O(1) Query API: Retrieves the compiled population points for a chunk coordinate.
static func get_population_for_chunk(chunk_pos: Vector3i) -> Array[PopulationPoint]:
	_ensure_populated_registry()
	
	if _population_registry.has(chunk_pos):
		# Explicit casting to guarantee typed Array safety
		var points: Array = _population_registry[chunk_pos] as Array
		var typed_points: Array[PopulationPoint] = []
		for point: Variant in points:
			if point is PopulationPoint:
				typed_points.append(point as PopulationPoint)
		return typed_points
		
	return []


static func _ensure_populated_registry() -> void:
	if _initialized:
		return
	_initialized = true
	
	_populate_castle_spawns()
	_populate_oasis_spawns()
	_populate_harbor_spawns()
	_populate_nether_spawns()
	_populate_cabin_spawns()
	_populate_lair_spawns()


static func _populate_castle_spawns() -> void:
	var c_12_12 := Vector3i(12, 12, 12)
	_population_registry[c_12_12] = [
		PopulationPoint.new(false, 102, Vector3(197.5, 13.0, 224.5)), # Guard
		PopulationPoint.new(false, 102, Vector3(202.5, 13.0, 224.5)), # Guard
		PopulationPoint.new(true, 202, Vector3(196.5, 13.0, 218.5)),  # Streetlight
		PopulationPoint.new(true, 202, Vector3(203.5, 13.0, 218.5)),  # Streetlight
		PopulationPoint.new(true, 203, Vector3(194.5, 13.0, 212.5))   # Campfire
	]
	
	var c_12_11 := Vector3i(12, 12, 11)
	_population_registry[c_12_11] = [
		PopulationPoint.new(false, 102, Vector3(197.5, 13.0, 185.5)), # Guard
		PopulationPoint.new(false, 102, Vector3(202.5, 13.0, 185.5)), # Guard
		PopulationPoint.new(false, 100, Vector3(200.5, 14.0, 186.5))  # Villager
	]
	
	_populate_castle_treasury_and_inner_defense()


static func _populate_castle_treasury_and_inner_defense() -> void:
	var c_13_11 := Vector3i(13, 12, 11)
	_population_registry[c_13_11] = [
		PopulationPoint.new(false, 102, Vector3(208.5, 19.5, 188.5)), # Guard
		PopulationPoint.new(true, 200, Vector3(210.5, 20.0, 185.5))   # Chest
	]
	
	var c_11_11 := Vector3i(11, 12, 11)
	_population_registry[c_11_11] = [
		PopulationPoint.new(false, 102, Vector3(191.5, 13.0, 189.5))  # Guard
	]


static func _populate_oasis_spawns() -> void:
	var c_neg10_15 := Vector3i(-10, 12, 15)
	_population_registry[c_neg10_15] = [
		PopulationPoint.new(true, 200, Vector3(-159.0, 22.0, 250.0)), # Chest
		PopulationPoint.new(false, 10, Vector3(-150.0, 16.0, 246.0)),  # Zombie
		PopulationPoint.new(false, 10, Vector3(-159.0, 16.0, 254.0))   # Zombie
	]


static func _populate_harbor_spawns() -> void:
	var c_neg9_0 := Vector3i(-9, 12, 0)
	_population_registry[c_neg9_0] = [
		PopulationPoint.new(false, 100, Vector3(-138.5, 12.0, 3.5)),  # Villager
		PopulationPoint.new(false, 101, Vector3(-136.5, 12.0, -3.5)), # Merchant
		PopulationPoint.new(false, 102, Vector3(-131.5, 12.5, -4.5))  # Guard
	]
	
	var c_neg10_0 := Vector3i(-10, 12, 0)
	_population_registry[c_neg10_0] = [
		PopulationPoint.new(false, 102, Vector3(-150.5, 17.5, 0.5)),  # Guard
		PopulationPoint.new(true, 200, Vector3(-146.5, 17.5, -2.5)),  # Chest
		PopulationPoint.new(false, 100, Vector3(-162.5, 7.5, -3.5))   # Villager
	]


static func _populate_nether_spawns() -> void:
	var c_neg19_neg19 := Vector3i(-19, 12, -19)
	_population_registry[c_neg19_neg19] = [
		PopulationPoint.new(true, 200, Vector3(-306.5, 16.0, -306.5)), # Chest
		PopulationPoint.new(false, 10, Vector3(-295.5, 9.5, -298.5)),  # Zombie
		PopulationPoint.new(false, 10, Vector3(-304.5, 9.5, -298.5)),  # Zombie
		PopulationPoint.new(false, 51, Vector3(-300.5, 9.5, -294.5))   # Colossus Boss
	]


static func _populate_cabin_spawns() -> void:
	var c_18_neg19 := Vector3i(18, 12, -19)
	_population_registry[c_18_neg19] = [
		PopulationPoint.new(false, 101, Vector3(302.5, 11.0, -297.5)), # Merchant
		PopulationPoint.new(false, 103, Vector3(292.5, 11.0, -292.5)), # Farmer
		PopulationPoint.new(false, 107, Vector3(300.5, 11.0, -300.5)), # Golem
		PopulationPoint.new(true, 200, Vector3(293.5, 17.0, -308.5))   # Chest
	]


static func _populate_lair_spawns() -> void:
	var c_neg7_6 := Vector3i(-7, 12, 6)
	_population_registry[c_neg7_6] = [
		PopulationPoint.new(false, 50, Vector3(-100.5, 16.0, 100.5))  # Lurker Boss
	]
