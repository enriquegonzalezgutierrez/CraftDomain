# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Registry mapping numeric IDs to dynamic Prop factories.
#              Decouples inert scenery props and interactive decorations (Chests,
#              Streetlights) from the living, mobile entity (Mob) subdomains.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively static and 
#   interactive prop registries, leaving AI-guided entities to MobRegistry.
# - Open-Closed Principle (OCP): Dynamically extensible. New scenery items 
#   can register their custom instantiation factories without modifying this file.
# - Dependency Inversion Principle (DIP): Pure domain class with zero dependencies 
#   on concrete Infrastructure paths. Factories are injected from Bootstrap.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/PropRegistry.gd
# ==============================================================================
class_name PropRegistry
extends RefCounted

## Dictionary storing numeric IDs and their respective Callable instantiation factories.
static var _spawners: Dictionary = {}


## Static registry API: Registers a new prop factory at runtime (OCP compliant).
static func register_prop(prop_id: int, factory: Callable) -> void:
	_spawners[prop_id] = factory


## Constructs and returns a Node3D representation if the prop ID exists.
static func create_prop(prop_id: int, pos: Vector3) -> Node:
	if _spawners.has(prop_id):
		var factory: Callable = _spawners[prop_id]
		return factory.call(pos) as Node
	return null


## Public API: Checks if a prop ID is registered in the database.
static func has_prop(prop_id: int) -> bool:
	return _spawners.has(prop_id)
