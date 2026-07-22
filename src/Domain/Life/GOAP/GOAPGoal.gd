# ==============================================================================
# Pathfile: res://src/Domain/Life/GOAP/GOAPGoal.gd
# Description: Pure Domain abstract base class representing a GOAP Goal.
#              Defines the desired world state an agent wishes to achieve 
#              and dynamic priority scaling to drive emergent behavior selection.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively defines motivations and 
#   desired outcomes, delegating the "how to get there" to the GOAP Planner.
# - Open-Closed Principle (OCP): Designed to be extended by concrete goals 
#   without modifying the planner algorithm.
# - Liskov Substitution Principle (LSP): Fully polymorphic priority evaluation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GOAPGoal
extends RefCounted

## Human-readable identifier for debugging and telemetry
var goal_name: String

## The default baseline priority. Higher priority goals are evaluated first.
var base_priority: float = 1.0

## Dictionary of states (String -> Variant) that this goal considers a 
## "success condition". The planner will chain actions until the world state 
## or blackboard matches these conditions.
var desired_state: Dictionary = {}


func _init(p_name: String, p_priority: float = 1.0) -> void:
	goal_name = p_name
	base_priority = p_priority


## Registers a specific state condition required to fulfill this goal.
func add_desired_state(key: String, value: Variant) -> void:
	desired_state[key] = value


## Evaluates if the current state satisfies all desired conditions for this goal.
func is_satisfied(current_state: Dictionary) -> bool:
	if desired_state.is_empty():
		return true
		
	for key: String in desired_state.keys():
		if not current_state.has(key) or current_state[key] != desired_state[key]:
			return false
	return true


# ==============================================================================
# VIRTUAL EVALUATION CONTRACTS (LSP Compliant)
# ==============================================================================

## Dynamic Validator: Determines if this goal is currently relevant.
func is_valid(blackboard: AIBlackboard) -> bool:
	var _bb := blackboard
	return true


## Priority Scaling: Evaluates the urgency of this goal dynamically.
func get_priority(blackboard: AIBlackboard) -> float:
	var _bb := blackboard
	return base_priority
