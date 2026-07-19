# ==============================================================================
# Pathfile: res://src/Domain/Life/GOAP/GOAPAction.gd
# Description: Pure Domain abstract base class for Goal-Oriented Action Planning.
#              Defines the preconditions, effects, and execution contract for a 
#              single atomic FSM-agnostic behavior (e.g., "Chop Wood", "Sleep").
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates individual atomic actions.
# - Open-Closed Principle (OCP): Inherited by concrete actions; closed to FSM edits.
# - Liskov Substitution Principle (LSP): Fully polymorphic action execution.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GOAPAction
extends RefCounted

## Human-readable identifier for debugging and telemetry
var action_name: String

## The abstract weight/cost of this action. The GOAP Planner uses A* to find 
## the sequence of actions with the lowest total cost to reach a Goal.
var cost: float = 1.0

## Dictionary of state requirements (String -> Variant) that must exist in the 
## world or blackboard for this action to be linked in the plan.
var preconditions: Dictionary = {}

## Dictionary of state changes (String -> Variant) that this action will 
## apply to the world/blackboard once successfully completed.
var effects: Dictionary = {}


func _init(p_name: String, p_cost: float = 1.0) -> void:
	action_name = p_name
	cost = p_cost


## Registers a required state for this action to be valid.
func add_precondition(key: String, value: Variant) -> void:
	preconditions[key] = value


## Registers a resulting state that this action will produce upon completion.
func add_effect(key: String, value: Variant) -> void:
	effects[key] = value


# ==============================================================================
# VIRTUAL EXECUTION CONTRACTS (LSP Compliant)
# ==============================================================================

## Dynamic Validator: Checks if the action is physically/contextually possible 
## in the current frame (e.g., "Is the target tree still standing?").
func is_contextually_valid(blackboard: AIBlackboard) -> bool:
	var _bb := blackboard # Avoid unused warning in abstract base
	return true


## Lifecycle Hook: Triggered once when the action becomes the active step in the plan.
func on_enter(blackboard: AIBlackboard) -> void:
	var _bb := blackboard
	pass


## Main Execution Loop: Runs every AI tick while the action is active.
## Must return true when the action is completely finished, signaling the 
## planner to advance to the next step. Returns false while still in progress.
func execute_step(blackboard: AIBlackboard, delta: float) -> bool:
	var _bb := blackboard
	var _d := delta
	assert(false, "[GOAPAction] execute_step() must be implemented by concrete subclass.")
	return true


## Lifecycle Hook: Triggered once when the action finishes or is interrupted.
func on_exit(blackboard: AIBlackboard) -> void:
	var _bb := blackboard
	pass
