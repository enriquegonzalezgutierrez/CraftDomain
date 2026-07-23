# ==============================================================================
# Pathfile: res://src/Domain/Life/IAIBehavior.gd
# Description: Pure Domain Strategy Interface defining the execution contract 
#              for custom, entity-specific AI behavior routines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
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
