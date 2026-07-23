# ==============================================================================
# Pathfile: res://src/Domain/Life/MobRegistry.gd
# Description: Pure Domain Registry managing entity factories, habitat rules,
#              spawn elevation zones, display name keys, and AI strategy bindings.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MobRegistry
extends RefCounted

enum Habitat {
	TERRESTRIAL, 
	AMPHIBIOUS,  
	AQUATIC      
}

enum SpawnZone {
	SURFACE,      # Open surface, structures, and building floors
	SUBTERRANEAN, # Caves, tunnels, and deep underground mines
	AQUATIC       # Water bodies and ocean depths
}

static var _spawners: Dictionary = {}
static var _habitats: Dictionary = {}
static var _spawn_zones: Dictionary = {}
static var _behaviors: Dictionary = {}
static var _display_names: Dictionary = {}


## Dynamic OCP API: Registers a custom mob factory, habitat, spawn zone, behavior, and display name key.
static func register_mob(
	spawn_id: int, 
	factory: Callable, 
	habitat: Habitat = Habitat.TERRESTRIAL, 
	default_behavior: IAIBehavior = null,
	spawn_zone: SpawnZone = SpawnZone.SURFACE,
	display_name_key: String = "INVENTORY_UNKNOWN"
) -> void:
	_spawners[spawn_id] = factory
	_habitats[spawn_id] = habitat
	_spawn_zones[spawn_id] = spawn_zone
	_display_names[spawn_id] = display_name_key
	if default_behavior != null:
		_behaviors[spawn_id] = default_behavior


## Constructs and returns an entity instance dynamically at the target position.
static func create_mob(spawn_id: int, pos: Vector3) -> Node:
	if not _spawners.has(spawn_id):
		return null
		
	var factory: Callable = _spawners[spawn_id]
	var mob := factory.call(pos) as Node
	
	if is_instance_valid(mob):
		if not (mob is PassiveEntity):
			push_error("[MobRegistry] Fatal: Factory returned raw node for ID %d without physics class!" % spawn_id)
			mob.queue_free()
			return null
		_rig_npc_ai_component(mob, spawn_id)
			
	return mob


static func _rig_npc_ai_component(mob: Node, spawn_id: int) -> void:
	var ai: Object = mob.get_node_or_null("NPCAIComponent")
	if not is_instance_valid(ai) and mob is PassiveEntity:
		var new_ai := NPCAIComponent.new()
		mob.add_child(new_ai)
		mob.ai_component = new_ai
		ai = new_ai
		
	_bind_behavior_if_missing(ai, spawn_id)


static func _bind_behavior_if_missing(ai: Object, spawn_id: int) -> void:
	if is_instance_valid(ai) and ai.get("active_behavior") == null and _behaviors.has(spawn_id):
		var original: IAIBehavior = _behaviors[spawn_id]
		if original != null:
			ai.set("active_behavior", original.duplicate())


## Returns the Habitat type registered for a given spawn ID.
static func get_mob_habitat(spawn_id: int) -> int:
	return _habitats.get(spawn_id, Habitat.TERRESTRIAL) as int


## Returns the SpawnZone registered for a given spawn ID (OCP Compliant).
static func get_mob_spawn_zone(spawn_id: int) -> SpawnZone:
	return _spawn_zones.get(spawn_id, SpawnZone.SURFACE) as SpawnZone


## Returns the display name key registered for a given spawn ID (OCP Compliant).
static func get_mob_display_name_key(spawn_id: int) -> String:
	return _display_names.get(spawn_id, "INVENTORY_UNKNOWN") as String


## Returns true if a spawn ID is registered in the database.
static func has_mob(spawn_id: int) -> bool:
	return _spawners.has(spawn_id)
