# ==============================================================================
# Pathfile: res://src/Domain/World/StructureLibrary.gd
# Description: Domain Service acting as a Registry and Router for voxel structure
#              blueprints. Provides dynamic registration (OCP compliant) and
#              delegates construction algorithms to concrete strategy classes.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages structural registrations,
#   fully decoupled from generation or terrain threading loops.
# - Open-Closed Principle (OCP): Extensible to mods and custom blueprints at runtime.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name StructureLibrary
extends RefCounted

## Dynamic registry mapping unique Structure IDs to their concrete IStructureBlueprint strategies.
static var _blueprints: Dictionary = {}


## Startup Initializer: Instantiates and registers the default set of 
## local structure, shrub, and tree blueprints (OCP/SOLID Compliant).
static func initialize_structures() -> void:
	_blueprints.clear()
	_register_biological_blueprints()
	_register_architectural_blueprints()


static func _register_biological_blueprints() -> void:
	# Biological Strategy Registry (Directly instantiates specialized tree/flora classes)
	register_blueprint(OakTreeBlueprint.new())
	register_blueprint(RedwoodTreeBlueprint.new())
	register_blueprint(GiantMushroomBlueprint.new())
	register_blueprint(SakuraTreeBlueprint.new())
	register_blueprint(UnderworldFungusBlueprint.new())
	register_blueprint(RoseBushBlueprint.new())
	register_blueprint(BirchTreeBlueprint.new())
	register_blueprint(DeadShrubBlueprint.new())


static func _register_architectural_blueprints() -> void:
	# Adaptive Architectural Registry (All historical and agricultural landmarks compiled in RAM)
	register_blueprint(WarpPipeBlueprint.new())           # ID 4: OCP Adaptive Warp Pipes
	register_blueprint(IceTempleBlueprint.new())          # ID 6: OCP Dynamic Ice Temples
	register_blueprint(NeonPyramidBlueprint.new())        # ID 7: OCP Adaptive Neon Pyramids
	register_blueprint(MarketCabinBlueprint.new())        # ID 8: OCP Dynamic Market Cabins
	register_blueprint(DecayedTempleBlueprint.new())      # ID 15: Adaptive Dungeon Ruins
	register_blueprint(GeothermalVentBlueprint.new())     # ID 16: Volcanic Magma Vents


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
