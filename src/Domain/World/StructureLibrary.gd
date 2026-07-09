# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic)
# Class: StructureLibrary
# Description: Domain Service acting as a Registry and Router for voxel structure
#              blueprints. Provides dynamic registration (OCP compliant) and
#              delegates construction algorithms to concrete strategy classes.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates structure routing 
#   and local blueprint instantiation.
# - Open-Closed Principle (OCP): Integrates a 100% procedural compiled engine.
#   All static template references and file parsers are completely removed,
#   reducing startup times to zero.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/StructureLibrary.gd
# ==============================================================================
class_name StructureLibrary
extends RefCounted

## Dynamic registry mapping unique Structure IDs to their concrete IStructureBlueprint strategies.
static var _blueprints: Dictionary = {}


## Startup Initializer: Instantiates and registers the default set of 
## local structure, shrub, and tree blueprints (OCP/SOLID Compliant).
static func initialize_structures() -> void:
	print("[StructureLibrary] Initializing 100% compiled procedural structure blueprints...")
	_blueprints.clear()
	
	# ==========================================================================
	# 1. BIOLOGICAL STRATEGY REGISTRY (Pure SOLID Procedural)
	# Directly instantiates specialized strategy classes to achieve 120 FPS.
	# ==========================================================================
	register_blueprint(OakTreeBlueprint.new())
	register_blueprint(RedwoodTreeBlueprint.new())
	register_blueprint(GiantMushroomBlueprint.new())
	register_blueprint(SakuraTreeBlueprint.new())
	register_blueprint(UnderworldFungusBlueprint.new())
	register_blueprint(RoseBushBlueprint.new())
	register_blueprint(BirchTreeBlueprint.new())
	register_blueprint(DeadShrubBlueprint.new())
	
	# ==========================================================================
	# 2. ADAPTIVE ARCHITECTURAL REGISTRY (Pure SOLID Procedural)
	# All historical, technological, and agricultural landmarks are compiled in RAM.
	# ==========================================================================
	register_blueprint(WarpPipeBlueprint.new())           # ID 4: OCP Adaptive Warp Pipes
	register_blueprint(AdaptiveMinePillarBlueprint.new())  # ID 5: OCP Adaptive Support Pillars
	register_blueprint(IceTempleBlueprint.new())          # ID 6: OCP Dynamic Ice Temples
	register_blueprint(NeonPyramidBlueprint.new())        # ID 7: OCP Adaptive Neon Pyramids
	register_blueprint(MarketCabinBlueprint.new())        # ID 8: OCP Dynamic Market Cabins
	register_blueprint(DynamicHarborPierBlueprint.new())  # ID 9: OCP Dynamic Harbor Piers
	register_blueprint(DecayedTempleBlueprint.new())      # ID 15: Adaptive Dungeon Ruins
	register_blueprint(GeothermalVentBlueprint.new())     # ID 16: Volcanic Magma Vents
	
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
