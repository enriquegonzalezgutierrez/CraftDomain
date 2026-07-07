# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Registry mapping numeric IDs to dynamic Mob factories 
#              and their specific environmental Habitat rules.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Only manages dynamic entity 
#                factories and their domain-level classification parameters.
#              - Open-Closed Principle (OCP): Encapsulates entity registrations 
#                and Habitat definitions internally. Adding a new creature only 
#                requires appending one line here.
#              - Liskov Substitution Principle (LSP): Instantiates any entity subclass 
#                polymorphically under the Node contract.
# HABITAT OVERHAUL (DDD):
#              - Added `Habitat` enum to strictly classify TERRESTRIAL, AMPHIBIOUS, 
#                and AQUATIC entities at the Domain level.
#              - This entirely decouples habitat logic from string-matching in 
#                Infrastructure AI and Spawning services.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/MobRegistry.gd
# ==============================================================================
class_name MobRegistry
extends RefCounted

## Domain Classification for environmental spawning and AI pathing rules
enum Habitat {
	TERRESTRIAL, # Restricted strictly to land (Grass, Dirt, Stone, Sand, Snow)
	AMPHIBIOUS,  # Capable of traversing both Land shores (Sand, Mud) and Water
	AQUATIC      # Restricted strictly to liquid blocks (Water)
}

## Dictionary storing numeric IDs and their respective Callable instantiation factories.
static var _spawners: Dictionary = {}

## Dictionary mapping numeric IDs to their specific Habitat rules.
static var _habitats: Dictionary = {}


## Startup Initializer: Instantiates and registers the default set of 
## dynamic entity spawning factories, keeping Bootstrap.gd clean.
static func initialize_mobs() -> void:
	print("[MobRegistry] Initializing and registering dynamic entity spawning factories...")
	_spawners.clear()
	_habitats.clear()
	
	# Wilderness Spawn Mappings (0-3)
	register_mob(0, func(pos: Vector3) -> Node: return PigEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(1, func(pos: Vector3) -> Node: return ChickenEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(2, func(pos: Vector3) -> Node: return SheepEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(3, func(pos: Vector3) -> Node: return CowEntity.new(pos), Habitat.TERRESTRIAL)
	
	# Villagers & Interactive NPCs (100-103)
	register_mob(100, func(pos: Vector3) -> Node: return VillagerEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(101, func(pos: Vector3) -> Node: return MerchantEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(102, func(pos: Vector3) -> Node: return GuardEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(103, func(pos: Vector3) -> Node: return FarmerEntity.new(pos), Habitat.TERRESTRIAL)
	
	# NPC Variety (Druid, Miner, and Android citizens: 104-106)
	register_mob(104, func(pos: Vector3) -> Node: return DruidEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(105, func(pos: Vector3) -> Node: return MinerEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(106, func(pos: Vector3) -> Node: return CyberCitizenEntity.new(pos), Habitat.TERRESTRIAL)
	
	# Defending Golems (ID 107)
	register_mob(107, func(pos: Vector3) -> Node: return GolemEntity.new(pos), Habitat.TERRESTRIAL)
	
	# Hostile Mobs (ZOMBIE registered as ID 10)
	register_mob(10, func(pos: Vector3) -> Node: return HostileEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(12, func(pos: Vector3) -> Node: return GargoyleEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(13, func(pos: Vector3) -> Node: return GoblinEntity.new(pos), Habitat.TERRESTRIAL)
	
	# Marine & Amphibious Wildlife
	register_mob(11, func(pos: Vector3) -> Node: return SharkEntity.new(pos), Habitat.AQUATIC)
	register_mob(210, func(pos: Vector3) -> Node: return OctopusEntity.new(pos), Habitat.AQUATIC)
	register_mob(201, func(pos: Vector3) -> Node: return TurtleEntity.new(pos), Habitat.AMPHIBIOUS)
	register_mob(208, func(pos: Vector3) -> Node: return CrabEntity.new(pos), Habitat.AMPHIBIOUS)
	
	# Extended Forest, Desert & Tropical Wildlife
	register_mob(204, func(pos: Vector3) -> Node: return FoxEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(205, func(pos: Vector3) -> Node: return BirdEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(206, func(pos: Vector3) -> Node: return CatEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(207, func(pos: Vector3) -> Node: return ParrotEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(209, func(pos: Vector3) -> Node: return ElephantEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(211, func(pos: Vector3) -> Node: return RaccoonEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(212, func(pos: Vector3) -> Node: return GrowlitheEntity.new(pos), Habitat.TERRESTRIAL)
	register_mob(213, func(pos: Vector3) -> Node: return MonkeyEntity.new(pos), Habitat.TERRESTRIAL)
	
	print("[MobRegistry] Initialization complete. Registered dynamic spawners count: ", _spawners.size())


## Static registry API: Registers a new entity factory and its habitat at runtime.
static func register_mob(spawn_id: int, factory: Callable, habitat: Habitat = Habitat.TERRESTRIAL) -> void:
	_spawners[spawn_id] = factory
	_habitats[spawn_id] = habitat


## Constructs and returns a Node3D representation if the spawn ID exists.
static func create_mob(spawn_id: int, pos: Vector3) -> Node:
	if _spawners.has(spawn_id):
		var factory: Callable = _spawners[spawn_id]
		return factory.call(pos) as Node
	return null


## Public API: Retrieves the strictly classified Habitat type for a given spawn ID.
static func get_mob_habitat(spawn_id: int) -> Habitat:
	if _habitats.has(spawn_id):
		return _habitats[spawn_id] as Habitat
	return Habitat.TERRESTRIAL


## Public API: Checks if a spawn ID is registered in the database.
static func has_mob(spawn_id: int) -> bool:
	return _spawners.has(spawn_id)
