# ==============================================================================
# Project: CraftDomain
# Description: Domain Service acting as a Registry and Router for voxel structure
#              blueprints. Provides dynamic registration (OCP compliant) and
#              delegates construction algorithms to concrete strategy classes,
#              closing this class to future modifications.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/StructureLibrary.gd
# ==============================================================================
class_name StructureLibrary
extends RefCounted

## Dynamic registry mapping unique Structure IDs to their concrete IStructureBlueprint strategies
static var _blueprints: Dictionary = {}

## Static registry API: Registers a concrete structure blueprint at runtime.
## This allows adding any number of new shapes/trees without modifying this file (Strict OCP).
static func register_blueprint(blueprint: IStructureBlueprint) -> void:
	if blueprint == null:
		return
		
	_blueprints[blueprint.get_structure_id()] = blueprint
	print("[StructureLibrary] Dynamic Structure Blueprint registered: [ID %d] %s" % [
		blueprint.get_structure_id(), 
		blueprint.get_script().get_global_name()
	])

## Public API: Retrieves a registered structure strategy by its ID.
static func get_blueprint(structure_id: int) -> IStructureBlueprint:
	if _blueprints.has(structure_id):
		return _blueprints[structure_id] as IStructureBlueprint
	return null
