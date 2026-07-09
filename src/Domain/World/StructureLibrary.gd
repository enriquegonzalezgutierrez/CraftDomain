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
# - Open-Closed Principle (OCP): Integrates a hybrid loading pipeline. 
#   * Artificial POIs are kept as data-driven JSON templates (Pipes, Piers, Cabins).
#   * Natural flora, ruins, and geothermal geysers are registered as high-performance 
#     individual procedural blueprint strategies, completely closing existing code 
#     to modifications when adding new biological, geological, or architectural species!
# - Dependency Inversion Principle (DIP): Communicates with abstract blueprints
#   inheriting `IStructureBlueprint`, keeping the registry closed to code modifications.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/StructureLibrary.gd
# ==============================================================================
class_name StructureLibrary
extends RefCounted

const STRUCTURE_DIR := "res://assets/structures/"

## Dynamic registry mapping unique Structure IDs to their concrete IStructureBlueprint strategies.
static var _blueprints: Dictionary = {}


## Startup Initializer: Instantiates and registers the default set of 
## local structure, shrub, and tree blueprints (OCP/SOLID Compliant).
static func initialize_structures() -> void:
	print("[StructureLibrary] Initializing hybrid procedural & data-driven structure blueprints...")
	_blueprints.clear()
	_ensure_directory_exists()
	
	# ==========================================================================
	# 1. BIOLOGICAL & ARCHITECTURAL STRATEGY REGISTRY (Pure SOLID Procedural)
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
	# CASE B: ADAPTIVE/PROCEDURAL SHRINES, RUINS, PILLARS, PIERS, CABINS & TEMPLES
	# ==========================================================================
	register_blueprint(DecayedTempleBlueprint.new())      # ID 15: Adaptive Dungeon Ruins
	register_blueprint(GeothermalVentBlueprint.new())     # ID 16: Volcanic Magma Vents
	register_blueprint(AdaptiveMinePillarBlueprint.new())  # ID 5: OCP Adaptive Support Pillars
	register_blueprint(DynamicHarborPierBlueprint.new())  # ID 9: OCP Dynamic Harbor Piers
	register_blueprint(MarketCabinBlueprint.new())        # ID 8: OCP Dynamic Market Cabins
	register_blueprint(IceTempleBlueprint.new())          # ID 6: OCP Dynamic Ice Temples
	register_blueprint(NeonPyramidBlueprint.new())        # ID 7: OCP Adaptive Neon Pyramids
	
	# ==========================================================================
	# 2. MANUFACTURED TEMPLATE REGISTRY (Data-Driven JSON Layouts)
	# Rigid POIs that never change shape remain data-driven for easy designer tuning.
	# ==========================================================================
	_register_template_safely(4, "warp_pipe.json")
	
	print("[StructureLibrary] Initialization complete. Registered blueprints count: ", _blueprints.size())


static func _ensure_directory_exists() -> void:
	if not DirAccess.dir_exists_absolute(STRUCTURE_DIR):
		Doc_dir_exists_absolute_error_handling()


static func Doc_dir_exists_absolute_error_handling() -> void:
	DirAccess.make_dir_recursive_absolute(STRUCTURE_DIR)
	print("[StructureLibrary] Created missing structures directory: ", STRUCTURE_DIR)


## Safely verifies file existence before loading and registering the template strategy
static func _register_template_safely(structure_id: int, file_name: String) -> void:
	var path := STRUCTURE_DIR + file_name
	
	# Complies with Godot export pipelines by checking both directories
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		register_blueprint(TemplateStructureBlueprint.new(structure_id, path))
	else:
		push_error("[StructureLibrary ERROR] Could not find blueprint template at: " + path)


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
