# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Life & Entities / Registries)
# Class: MobRegistry
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# Description: Pure Domain Registry managing abstract entity factories, habitat 
#              rules, and polymorphic behavior strategy bindings.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively classifies spawn ID bounds,
#   delegating physical rigging to specialized sub-methods.
# - Open-Closed Principle (OCP): closed to modifications. Purged hardcoded match 
#   tables; registers behaviors dynamically.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# ==============================================================================
class_name MobRegistry
extends RefCounted

## Domain Classification for environmental spawning and AI pathing rules
enum Habitat {
	TERRESTRIAL, # Restricted strictly to land (Grass, Dirt, Stone, Sand, Snow)
	AMPHIBIOUS,  # Capable of traversing both Land shores (Sand, Mud) and Water
	AQUATIC      # Restricted strictly to liquid blocks (Water)
}

## In-memory databases mapping spawn IDs to abstract creators and parameters
static var _spawners: Dictionary = {} # int -> Callable
static var _habitats: Dictionary = {} # int -> Habitat
static var _behaviors: Dictionary = {} # int -> IAIBehavior


## Dynamic Registry API: Binds a custom factory Callable, habitat rules, and 
## optional default AI behavior strategy to a unique spawn ID.
static func register_mob(spawn_id: int, factory: Callable, habitat: Habitat = Habitat.TERRESTRIAL, default_behavior: IAIBehavior = null) -> void:
	_spawners[spawn_id] = factory
	_habitats[spawn_id] = habitat
	if default_behavior != null:
		_behaviors[spawn_id] = default_behavior


## Resolves and constructs a physical entity node dynamically at the target position.
## Automatically decorates the node with its registered AI behavior strategy if applicable.
static func create_mob(spawn_id: int, pos: Vector3) -> Node:
	if not _spawners.has(spawn_id):
		return null
		
	var factory: Callable = _spawners[spawn_id]
	var mob := factory.call(pos) as Node
	
	if is_instance_valid(mob):
		# Ghost Shield: If the factory returns a raw CharacterBody3D without a physical class script attached
		# (e.g. not extending PassiveEntity), we reject the spawn to prevent memory leaks and zombie processes.
		if not (mob is PassiveEntity):
			push_error("[MobRegistry] Fatal: Factory returned a raw node for Spawn ID %d without a physics class!" % spawn_id)
			mob.queue_free()
			return null
			
		_rig_npc_ai_component(mob, spawn_id)
			
	return mob


## Rigging helper decomposing complex node assignments to fit 20-line limits (SRP)
static func _rig_npc_ai_component(mob: Node, spawn_id: int) -> void:
	var ai: Object = mob.get_node_or_null("NPCAIComponent")
	if not is_instance_valid(ai) and mob is PassiveEntity:
		var new_ai := NPCAIComponent.new()
		mob.add_child(new_ai)
		mob.ai_component = new_ai
		ai = new_ai
		
	if is_instance_valid(ai) and ai.get("active_behavior") == null:
		if _behaviors.has(spawn_id):
			var original: IAIBehavior = _behaviors[spawn_id]
			if original != null:
				ai.set("active_behavior", original.duplicate())


## Public API: Retrieves the strictly classified Habitat type for a given spawn ID.
static func get_mob_habitat(spawn_id: int) -> int:
	if _habitats.has(spawn_id):
		return _habitats[spawn_id] as int
	return Habitat.TERRESTRIAL as int


## Public API: Checks if a spawn ID is registered in the database.
static func has_mob(spawn_id: int) -> bool:
	return _spawners.has(spawn_id)
