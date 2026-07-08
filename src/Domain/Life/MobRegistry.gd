# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic)
# Class: MobRegistry
# Description: Refactored Domain Registry responsible for managing dynamic mob 
#              factories, habitat rules, and dynamic behavior strategy injection.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates entity classification and 
#   creation logic from active gameplay coordinates and visual nodes.
# - Open-Closed Principle (OCP): Dynamic strategy decoration intercepts creations, 
#   enabling automated behavior injection for all entities while keeping factories 
#   closed to modification.
# - Liskov Substitution Principle (LSP): Instantiates and processes any entity 
#   subclass polimorphically under the Node and Strategy contracts.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name MobRegistry
extends RefCounted

## Domain Classification for environmental spawning and AI pathing rules
enum Habitat {
	TERRESTRIAL, # Restricted strictly to land (Grass, Dirt, Stone, Sand, Snow)
	AMPHIBIOUS,  # Capable of traversing both Land shores (Sand, Mud) and Water
	AQUATIC      # Restricted strictly to liquid blocks (Water)
}

## Dictionary storing numeric IDs and their respective Callable instantiation factories
static var _spawners: Dictionary = {}

## Dictionary mapping numeric IDs to their specific Habitat rules
static var _habitats: Dictionary = {}


## Startup Initializer: Instantiates and registers the default set of 
## dynamic entity spawning factories, keeping Bootstrap.gd clean
static func initialize_mobs() -> void:
	print("[MobRegistry] Initializing and registering master dynamic entity spawning factories...")
	_spawners.clear()
	_habitats.clear()
	
	# ==========================================================================
	# A. WILDERNESS FAUNA SCENE-BASED TEMPLATES (ID 0..213)
	# ==========================================================================
	
	# Wild Pig (ID 0)
	register_mob(0, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/pig_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return PigEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Prairie Chicken (ID 1)
	register_mob(1, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/chicken_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return ChickenEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Sea Turtle (ID 201)
	register_mob(201, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/turtle_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return TurtleEntity.new(pos)
	, Habitat.AMPHIBIOUS)
	
	# Colossal Elephant (ID 209)
	register_mob(209, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/elephant_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return ElephantEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Red Fox (ID 204)
	register_mob(204, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/fox_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return FoxEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Domestic Cat (ID 206)
	register_mob(206, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/cat_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return CatEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Forest Raccoon (ID 211)
	register_mob(211, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/raccoon_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return RaccoonEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Fiery Growlithe (ID 212)
	register_mob(212, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/growlithe_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return GrowlitheEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Tropical Monkey (ID 213)
	register_mob(213, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/monkey_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return MonkeyEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Flying Yellow Bird (ID 205)
	register_mob(205, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/bird_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return BirdEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Tropical Parrot (ID 207)
	register_mob(207, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/parrot_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return ParrotEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Beach Crab (ID 208)
	register_mob(208, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/crab_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return CrabEntity.new(pos)
	, Habitat.AMPHIBIOUS)
	
	# Deep-water Octopus (ID 210)
	register_mob(210, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/octopus_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return OctopusEntity.new(pos)
	, Habitat.AQUATIC)
	
	# ==========================================================================
	# B. HOSTILE & DEFENDER SCENE-BASED TEMPLATES (ID 10..107)
	# ==========================================================================
	
	# Great White Shark (ID 11)
	register_mob(11, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/shark_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return SharkEntity.new(pos)
	, Habitat.AQUATIC)
	
	# Gothic Gargoyle (ID 12)
	register_mob(12, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/gargoyle_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return GargoyleEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Hostile Goblin (ID 13)
	register_mob(13, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/goblin_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return GoblinEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Cave Zombie (ID 10)
	register_mob(10, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/zombie_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return HostileEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Iron Golem (ID 107)
	register_mob(107, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/golem_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return GolemEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# ==========================================================================
	# C. HUMAN NPC SCENE-BASED TEMPLATES (ID 100..106)
	# ==========================================================================
	
	# Common Villager (ID 100)
	register_mob(100, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/villager_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return VillagerEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Sentry Guard (ID 102)
	register_mob(102, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/guard_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return GuardEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Agricultural Farmer (ID 103)
	register_mob(103, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/farmer_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return FarmerEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Forest Druid (ID 104)
	register_mob(104, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/druid_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return DruidEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Bazaar Merchant (ID 101)
	register_mob(101, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/merchant_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return MerchantEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Cave Miner (ID 105)
	register_mob(105, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/miner_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return MinerEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# Android CyberCitizen (ID 106)
	register_mob(106, func(pos: Vector3) -> Node:
		var scene_path := "res://src/Infrastructure/Life/cyber_citizen_entity.tscn"
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var inst := scene.instantiate() as CharacterBody3D
				inst.position = pos
				return inst
		return CyberCitizenEntity.new(pos)
	, Habitat.TERRESTRIAL)
	
	# ==========================================================================
	# D. PROCEDURAL MULTI-BOX FALLBACK CODES (Livestock)
	# ==========================================================================
	
	# Fluffy Sheep (ID 2)
	register_mob(2, func(pos: Vector3) -> Node: return SheepEntity.new(pos), Habitat.TERRESTRIAL)
	
	# Clay Cow (ID 3)
	register_mob(3, func(pos: Vector3) -> Node: return CowEntity.new(pos), Habitat.TERRESTRIAL)
	
	print("[MobRegistry] Master initialization finished. Total registered dynamic spawners count: ", _spawners.size())


## Static registry API: Registers a new entity factory and its habitat at runtime
static func register_mob(spawn_id: int, factory: Callable, habitat: Habitat = Habitat.TERRESTRIAL) -> void:
	_spawners[spawn_id] = factory
	_habitats[spawn_id] = habitat


## Constructs and returns a Node3D representation, injecting the specialized 
## behavior strategy dynamically on creation (DIP/OCP decoration pattern)
static func create_mob(spawn_id: int, pos: Vector3) -> Node:
	if _spawners.has(spawn_id):
		var factory: Callable = _spawners[spawn_id]
		var mob := factory.call(pos) as Node
		
		if is_instance_valid(mob):
			_inject_behavior_strategy(spawn_id, mob)
		return mob
	return null


## Dynamic strategy decorator: Analyzes spawned IDs and injects matching strategies (OCP/SOLID compliant)
static func _inject_behavior_strategy(spawn_id: int, mob: Node) -> void:
	var ai: NPCAIComponent = mob.get_node_or_null("NPCAIComponent") as NPCAIComponent
	
	# Recovery shield: programmatically add the component if missing from standard models
	if not is_instance_valid(ai) and mob is PassiveEntity:
		ai = NPCAIComponent.new()
		mob.add_child(ai)
		mob.ai_component = ai
		
	if is_instance_valid(ai):
		# Only inject if a specialized script hasn't already defined its strategy
		if ai.active_behavior == null:
			match spawn_id:
				10, 12, 13: # Zombie, Gargoyle, Goblin
					ai.active_behavior = ZombieAIBehavior.new()
				102, 107: # Guard, Iron Golem
					ai.active_behavior = GuardAIBehavior.new()
				103: # Farmer
					ai.active_behavior = FarmerAIBehavior.new()
				0, 1, 2, 3, 11, 201, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213: # All Wildlife species
					ai.active_behavior = FaunaAIBehavior.new()


## Public API: Retrieves the strictly classified Habitat type for a given spawn ID
static func get_mob_habitat(spawn_id: int) -> int:
	if _habitats.has(spawn_id):
		return _habitats[spawn_id] as int
	return 0


## Public API: Checks if a spawn ID is registered in the database
static func has_mob(spawn_id: int) -> bool:
	return _spawners.has(spawn_id)
