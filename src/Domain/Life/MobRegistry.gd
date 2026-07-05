# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Registry mapping numeric IDs to dynamic Mob factories.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Only manages dynamic entity 
#                factories and instantiation parameters for living, AI-driven actors.
#              - Open-Closed Principle (OCP): Encapsulates entity registrations 
#                internally on startup, allowing new species (like Fox 204, Bird 205, Cat 206, Parrot 207, Crab 208, Elephant 209, Octopus 210, Shark 11, Raccoon 211, Growlithe 212 & Gargoyle 12) 
#                to be registered without breaking the boot composition root.
#              - Liskov Substitution Principle (LSP): Instantiates any entity subclass 
#                polymorphically under the Node contract.
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
	
	# Wilderness Spawn Mappings (0-3)
	register_mob(0, func(pos: Vector3) -> Node: return PigEntity.new(pos))
	register_mob(1, func(pos: Vector3) -> Node: return ChickenEntity.new(pos))
	register_mob(2, func(pos: Vector3) -> Node: return SheepEntity.new(pos))
	register_mob(3, func(pos: Vector3) -> Node: return CowEntity.new(pos))
	
	# Villagers & Interactive NPCs (100-103)
	register_mob(100, func(pos: Vector3) -> Node: return VillagerEntity.new(pos))
	register_mob(101, func(pos: Vector3) -> Node: return MerchantEntity.new(pos))
	register_mob(102, func(pos: Vector3) -> Node: return GuardEntity.new(pos))
	register_mob(103, func(pos: Vector3) -> Node: return FarmerEntity.new(pos))
	
	# NPC Variety (Druid, Miner, and Android citizens: 104-106)
	register_mob(104, func(pos: Vector3) -> Node: return DruidEntity.new(pos))
	register_mob(105, func(pos: Vector3) -> Node: return MinerEntity.new(pos))
	register_mob(106, func(pos: Vector3) -> Node: return CyberCitizenEntity.new(pos))
	
	# Defending Golems (ID 107)
	register_mob(107, func(pos: Vector3) -> Node: return GolemEntity.new(pos))
	
	# Hostile Mobs (ZOMBIE registered as ID 10)
	register_mob(10, func(pos: Vector3) -> Node: return HostileEntity.new(pos))
	
	# Marine Wildlife (Sea Turtle registered as ID 201)
	register_mob(201, func(pos: Vector3) -> Node: return TurtleEntity.new(pos))
	
	# ==========================================================================
	# FOREST, DOMESTIC, TROPICAL, MARINE, DESERT, SAVANNAH & HOSTILE WILDLIFE ADDITIONS
	# - Fox registered under ID 204
	# - Flying Bird registered under ID 205
	# - Domestic Cat registered under ID 206
	# - Tropical Parrot registered under ID 207
	# - Beach Crab registered under ID 208
	# - Colossal Elephant registered under ID 209
	# - Deep-water Octopus registered under ID 210
	# - Great White Shark registered under ID 11
	# - Forest Raccoon registered under ID 211
	# - Fiery Growlithe registered under ID 212
	# - Nocturnal Gargoyle registered under ID 12
	# ==========================================================================
	register_mob(204, func(pos: Vector3) -> Node: return FoxEntity.new(pos))
	register_mob(205, func(pos: Vector3) -> Node: return BirdEntity.new(pos))
	register_mob(206, func(pos: Vector3) -> Node: return CatEntity.new(pos))
	register_mob(207, func(pos: Vector3) -> Node: return ParrotEntity.new(pos))
	register_mob(208, func(pos: Vector3) -> Node: return CrabEntity.new(pos))
	register_mob(209, func(pos: Vector3) -> Node: return ElephantEntity.new(pos))
	register_mob(210, func(pos: Vector3) -> Node: return OctopusEntity.new(pos))
	register_mob(11, func(pos: Vector3) -> Node: return SharkEntity.new(pos))
	register_mob(211, func(pos: Vector3) -> Node: return RaccoonEntity.new(pos))
	register_mob(212, func(pos: Vector3) -> Node: return GrowlitheEntity.new(pos))
	register_mob(12, func(pos: Vector3) -> Node: return GargoyleEntity.new(pos))
	
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
