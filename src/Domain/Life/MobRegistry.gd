# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Registry mapping numeric IDs to dynamic Mob factories.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Only manages dynamic entity 
#                factories and instantiation parameters.
#              - Open-Closed Principle (OCP): Encapsulates default entity registrations 
#                internally on startup, removing registration bloat from Bootstrap.
#              UPDATED:
#              - Registered the new physical 3D Streetlight Entity as Prop ID `202` 
#                to support spawning robust, non-floating, voxel-free lampposts.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/MobRegistry.gd
# ==============================================================================
class_name MobRegistry
extends RefCounted

## Dictionary storing numeric IDs and their respective Callable instantiation factories.
static var _spawners: Dictionary = {}


## Startup Initializer: Instantiates and registers the default set of 
## dynamic entity spawning factories, keeping Bootstrap.gd clean.
static func initialize_mobs() -> void:
	print("[MobRegistry] Initializing and registering dynamic entity spawning factories...")
	_spawners.clear()
	
	# Wildlife Spawn Mappings (0-3)
	register_mob(0, func(pos: Vector3) -> Node: return PigEntity.new(pos))
	register_mob(1, func(pos: Vector3) -> Node: return ChickenEntity.new(pos))
	register_mob(2, func(pos: Vector3) -> Node: return SheepEntity.new(pos))
	register_mob(3, func(pos: Vector3) -> Node: return CowEntity.new(pos))
	
	# Villagers & Interactive NPCs (100-103)
	register_mob(100, func(pos: Vector3) -> Node: return VillagerEntity.new(pos))
	register_mob(101, func(pos: Vector3) -> Node: return MerchantEntity.new(pos))
	register_mob(102, func(pos: Vector3) -> Node: return GuardEntity.new(pos))
	register_mob(103, func(pos: Vector3) -> Node: return FarmerEntity.new(pos))
	
	# NPC VARIETY OVERHAUL: Register Druid, Miner, and Android citizens (104-106)
	register_mob(104, func(pos: Vector3) -> Node: return DruidEntity.new(pos))
	register_mob(105, func(pos: Vector3) -> Node: return MinerEntity.new(pos))
	register_mob(106, func(pos: Vector3) -> Node: return CyberCitizenEntity.new(pos))
	
	# --- MOVIE OVERHAUL: Register the Iron Golem (ID 107) ---
	register_mob(107, func(pos: Vector3) -> Node: return GolemEntity.new(pos))
	
	# Hostile Mobs (ZOMBIE registered as ID 10)
	register_mob(10, func(pos: Vector3) -> Node: return HostileEntity.new(pos))
	
	# Interactive Props (Loot Chests and Entities)
	register_mob(200, func(pos: Vector3) -> Node: 
		var chest := ChestEntity.new()
		chest.position = pos
		return chest
	)
	
	# MARINE OVERHAUL: Register the Sea Turtle
	register_mob(201, func(pos: Vector3) -> Node: return TurtleEntity.new(pos))
	
	# ---> REGISTRATION OF 3D STREETLIGHT PROP <---
	# Registering our gorgeous 3D Streetlight Entity as Prop ID `202`
	register_mob(202, func(pos: Vector3) -> Node: 
		var light := StreetlightEntity.new()
		light.position = pos
		return light
	)
	
	print("[MobRegistry] Initialization complete. Registered dynamic spawners count: ", _spawners.size())


## Static registry API: Registers a new entity factory at runtime.
static func register_mob(spawn_id: int, factory: Callable) -> void:
	_spawners[spawn_id] = factory


## Constructs and returns a Node3D representation if the spawn ID exists.
static func create_mob(spawn_id: int, pos: Vector3) -> Node:
	if _spawners.has(spawn_id):
		var factory: Callable = _spawners[spawn_id]
		return factory.call(pos) as Node
	return null


## Public API: Checks if a spawn ID is registered in the database.
static func has_mob(spawn_id: int) -> bool:
	return _spawners.has(spawn_id)
