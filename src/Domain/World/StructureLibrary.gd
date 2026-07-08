# ==============================================================================
# Project: CraftDomain
# Description: Domain Service acting as a Registry and Router for voxel structure
#              blueprints. Provides dynamic registration (OCP compliant) and
#              delegates construction algorithms to concrete strategy classes.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates structure routing 
#   and local blueprint instantiation.
# - Open-Closed Principle (OCP): Integrates a hybrid loading pipeline. 
#   * Artificial POIs are kept as data-driven JSON templates (Pipes, Piers, Cabins).
#   * Natural flora are registered as high-performance procedural strategies 
#     (`ProceduralTreeBlueprint`), completely eliminating biological JSON files.
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
	# 1. BIOLOGICAL STRATEGY REGISTRY (Procedural Voxel Growth - 120 FPS Boost)
	# Directly instantiates compiled math generators, avoiding slow JSON parsing.
	# ==========================================================================
	register_blueprint(ProceduralTreeBlueprint.new(ProceduralTreeBlueprint.Species.OAK))
	register_blueprint(ProceduralTreeBlueprint.new(ProceduralTreeBlueprint.Species.REDWOOD))
	register_blueprint(ProceduralTreeBlueprint.new(ProceduralTreeBlueprint.Species.GIANT_MUSHROOM))
	register_blueprint(ProceduralTreeBlueprint.new(ProceduralTreeBlueprint.Species.SAKURA))
	register_blueprint(ProceduralTreeBlueprint.new(ProceduralTreeBlueprint.Species.UNDERWORLD_FUNGUS))
	register_blueprint(ProceduralTreeBlueprint.new(ProceduralTreeBlueprint.Species.ROSE_BUSH))
	register_blueprint(ProceduralTreeBlueprint.new(ProceduralTreeBlueprint.Species.BIRCH))
	register_blueprint(ProceduralTreeBlueprint.new(ProceduralTreeBlueprint.Species.DEAD_SHRUB))
	
	# ==========================================================================
	# 2. MANUFACTURED TEMPLATE REGISTRY (Data-Driven JSON Layouts)
	# Rigid POIs that never change shape remain data-driven for easy designer tuning.
	# ==========================================================================
	_register_template_safely(4, "warp_pipe.json")
	_register_template_safely(5, "mine_pillar.json")
	_register_template_safely(6, "ice_temple.json")
	_register_template_safely(7, "neon_pyramid.json")
	_register_template_safely(8, "market_cabin.json")
	_register_template_safely(9, "harbor_pier.json")
	
	print("[StructureLibrary] Initialization complete. Registered blueprints count: ", _blueprints.size())


static func _ensure_directory_exists() -> void:
	if not DirAccess.dir_exists_absolute(STRUCTURE_DIR):
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
