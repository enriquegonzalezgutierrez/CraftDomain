# ==============================================================================
# Pathfile: res://src/Domain/Life/GOAP/GOAPGoal.gd
# Description: Pure Domain abstract base class representing a GOAP Goal.
#              Defines the desired world state an agent wishes to achieve 
#              and dynamic priority scaling to drive emergent behavior selection.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively defines motivations and 
#   desired outcomes, delegating the "how to get there" to the GOAP Planner.
# - Open-Closed Principle (OCP): Designed to be extended by concrete goals 
#   (e.g., 'SleepGoal', 'WorkGoal') without modifying the planner algorithm.
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


# ==============================================================================
# VIRTUAL EVALUATION CONTRACTS (LSP Compliant)
# ==============================================================================

## Dynamic Validator: Determines if this goal is currently relevant.
## For example, a "Sleep" goal is only valid if CelestialService says it's night.
func is_valid(blackboard: AIBlackboard) -> bool:
	var _bb := blackboard # Avoid unused parameter warning in abstract base
	return true


## Priority Scaling: Evaluates the urgency of this goal dynamically.
## For example, a "EatFood" goal's priority might increase as the NPC gets hungrier.
func get_priority(blackboard: AIBlackboard) -> float:
	var _bb := blackboard
	return base_priority
