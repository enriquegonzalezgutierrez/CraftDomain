# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic)
# Class: IAIBehavior
# Description: Pure Domain Strategy Interface defining the execution contract 
#              for custom, entity-specific AI behavior routines.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively defines the behavioral
#   execution boundary, decoupling decision-making processes from physical 
#   movement structures.
# - Open-Closed Principle (OCP): Enables the addition of infinite unique 
#   AI patterns (such as farming, aggressive chasing, and mining) without 
#   modifying existing entity base controllers or monolithic AI classes.
# - Liskov Substitution Principle (LSP): Serves as a polymorphic contract. 
#   Any concrete strategy subclass can be injected into the coordinating AI 
#   component and processed seamlessly without runtime exceptions.
# - Dependency Inversion Principle (DIP): Refactored to depend on Godot's abstract
#   'Object' base instead of concrete framework nodes ('CharacterBody3D', 'Node'),
#   completely purging framework leakages from the pure Domain layer.
# ==============================================================================
class_name IAIBehavior
extends Resource

## OCP Fallback Flag: If set to true (e.g., Zombies, Wildlife), this behavior 
## strategy completely overrides and intercepts the generic wander schedules.
## If false (e.g., Guards, Farmers in repose), the AI Component is allowed 
## to run standard fallback village routines in between work cycles.
@export var overrides_wandering: bool = false


## Contract: Evaluates environmental states and executes specialized logical 
## routines for the host character.
## [param host]: The abstract actor context. Must expose APIs for location, 
##               velocity, collision query, and metadata manipulation.
## [param delta]: The physics execution frame-time step in seconds.
func evaluate_and_execute(host: Object, delta: float) -> void:
	# Avoid unused parameter warnings in the abstract interface contract
	var _host_ref := host
	var _d_val := delta
	
	assert(false, "[IAIBehavior ERROR] evaluate_and_execute must be implemented by a concrete subclass.")


## Virtual Contract (LSP Compliant): Returns the current active state/task name 
## of this behavior strategy as a human-readable string for telemetry.
## Defaults to "IDLE" if not overridden by the subclass.
func get_active_state_name(host: Object) -> String:
	var _host_ref := host # Avoid unused variable warning
	return "IDLE"
