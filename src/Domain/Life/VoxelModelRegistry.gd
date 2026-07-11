# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Registries)
# Class: VoxelModelRegistry
# Description: Pure Domain Registry managing the binding and lookup of 
#              IVoxelModelBuilder strategy classes.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the storage and 
#   lookup of dynamic voxel model configurations.
# - Open-Closed Principle (OCP): Completely closed to modifications. Monolithic 
#   hardcoded constructors have been decoupled. Adding new voxel NPC roles 
#   is done dynamically at runtime via `register_builder()`, without modifying 
#   any other engine systems.
# ==============================================================================
class_name VoxelModelRegistry
extends RefCounted

## Dynamic OCP database mapping Role IDs (ints) to their respective IVoxelModelBuilder strategies
static var _builders: Dictionary = {}


## Dynamic Registry API: Binds a custom model builder strategy to a specific Role ID.
## Enables mods, plugins, or expansions to inject custom voxel models at runtime.
static func register_builder(role_id: int, builder: IVoxelModelBuilder) -> void:
	_builders[role_id] = builder
	print("[VoxelModelRegistry] Registered dynamic model builder for Role ID: ", role_id)


## Dynamic Router API: Resolves and returns the registered builder strategy for a given Role ID.
## Automatically falls back to the Common Villager (ID 0) to prevent crashes on missing roles.
static func get_builder(role_id: int) -> IVoxelModelBuilder:
	if _builders.has(role_id):
		return _builders[role_id] as IVoxelModelBuilder
		
	# Safe Fallback to Common Villager (ID 0)
	if _builders.has(0):
		return _builders[0] as IVoxelModelBuilder
		
	return null


## Initializer: Automatically populates and binds the default set of 
## compiled, high-performance voxel models on game boot.
static func initialize_registry() -> void:
	print("[VoxelModelRegistry] Initializing and compiling baseline voxel models...")
	_builders.clear()
	
	# We compile and bind the 7 default roles in RAM instantly
	register_builder(0, VillagerModelBuilder.new()) # ID 0: Common Villager
	register_builder(1, MerchantModelBuilder.new()) # ID 1: Shopkeeper Merchant
	register_builder(2, GuardModelBuilder.new())    # ID 2: Armored Guard Knight
	register_builder(3, FarmerModelBuilder.new())   # ID 3: Agricultural Farmer
	register_builder(4, MinerModelBuilder.new())    # ID 4: Cavern Spotlight Miner
	register_builder(5, DruidModelBuilder.new())    # ID 5: Nature Forest Druid
	register_builder(6, GolemModelBuilder.new())    # ID 6: Colossus Iron Golem
	
	print("[VoxelModelRegistry] Baseline initialization finished. Active builders: ", _builders.size())
