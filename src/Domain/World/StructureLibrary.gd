# ==============================================================================
# Project: CraftDomain
# Description: Domain Service acting as a Registry and Router for voxel structure
#              blueprints. Provides dynamic registration (OCP compliant) and
#              delegates construction algorithms to concrete strategy classes.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Isolates structure routing 
#                and local blueprint instantiation.
#              - Open-Closed Principle (OCP): Registers default blueprints 
#                internally on startup, removing registration bloat from Bootstrap.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/StructureLibrary.gd
# ==============================================================================
class_name StructureLibrary
extends RefCounted

## Dynamic registry mapping unique Structure IDs to their concrete IStructureBlueprint strategies.
static var _blueprints: Dictionary = {}


## Startup Initializer: Instantiates and registers the default set of 
## local structure and tree blueprints, keeping Bootstrap.gd clean.
static func initialize_structures() -> void:
	print("[StructureLibrary] Initializing and registering local structure blueprints...")
	_blueprints.clear()
	
	register_blueprint(OakTreeBlueprint.new())
	register_blueprint(RedwoodTreeBlueprint.new())
	register_blueprint(GiantMushroomBlueprint.new())
	register_blueprint(WarpPipeBlueprint.new())
	register_blueprint(MinePillarBlueprint.new())
	register_blueprint(IceTempleBlueprint.new())
	register_blueprint(NeonPyramidBlueprint.new())
	register_blueprint(MarketCabinBlueprint.new())
	register_blueprint(HarborPierBlueprint.new())
	register_blueprint(SakuraTreeBlueprint.new())
	register_blueprint(UnderworldFungusBlueprint.new())
	
	print("[StructureLibrary] Initialization complete. Registered blueprints count: ", _blueprints.size())


## Static registry API: Registers a concrete structure blueprint at runtime.
static func register_blueprint(blueprint: IStructureBlueprint) -> void:
	if blueprint == null:
		return
		
	_blueprints[blueprint.get_structure_id()] = blueprint


## Public API: Retrieves a registered structure strategy by its unique ID.
static func get_blueprint(structure_id: int) -> IStructureBlueprint:
	if _blueprints.has(structure_id):
		return _blueprints[structure_id] as IStructureBlueprint
	return null
