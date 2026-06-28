# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Registry mapping numeric IDs to dynamic Mob factories.
#              SOLID COMPLIANCE: Adheres strictly to the Open-Closed Principle (OCP).
#              Allows injecting any new NPC or animal type into the spawning engine
#              without modifying the core procedural loop.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/MobRegistry.gd
# ==============================================================================
class_name MobRegistry
extends RefCounted

## Diccionario que almacena los IDs de generación y sus respectivas funciones de instanciación
static var _spawners: Dictionary = {}

## Registra un nuevo tipo de entidad, asociándolo a un ID y proporcionando un Callable de creación
static func register_mob(spawn_id: int, factory: Callable) -> void:
	_spawners[spawn_id] = factory
	print("[MobRegistry] Registered dynamic entity factory for Spawn ID: ", spawn_id)

## Construye e instancia el Node3D (CharacterBody3D o StaticBody3D) dinámicamente si el ID existe
static func create_mob(spawn_id: int, pos: Vector3) -> Node:
	if _spawners.has(spawn_id):
		var factory: Callable = _spawners[spawn_id]
		return factory.call(pos) as Node
	return null

## Verifica si un ID de generación está registrado en el diccionario
static func has_mob(spawn_id: int) -> bool:
	return _spawners.has(spawn_id)
