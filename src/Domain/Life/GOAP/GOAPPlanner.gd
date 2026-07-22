# ==============================================================================
# Pathfile: res://src/Domain/Life/GOAP/GOAPPlanner.gd
# Description: Pure Domain mathematical solver for Goal-Oriented Action Planning.
#              Optimized A* solver that handles pre-satisfied goals and 
#              complex state-space graph reconstructions.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively executes the planning 
#   algorithm without storing dynamic agent state.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GOAPPlanner
extends RefCounted

## Inner class representing a node in the A* state-space graph
class PlanNode:
	var parent: PlanNode
	var running_cost: float
	var state: Dictionary
	var action: GOAPAction
	
	func _init(p_parent: PlanNode, p_cost: float, p_state: Dictionary, p_action: GOAPAction) -> void:
		parent = p_parent
		running_cost = p_cost
		state = p_state
		action = p_action


## Calculates the optimal sequence of actions to satisfy the given Goal.
static func plan(goal: GOAPGoal, available_actions: Array[GOAPAction], initial_state: Dictionary) -> Array[GOAPAction]:
	if _are_conditions_met(goal.desired_state, initial_state):
		return []
		
	var leaves: Array[PlanNode] = []
	var start_node := PlanNode.new(null, 0.0, initial_state.duplicate(), null)
	
	var success := _build_graph(start_node, leaves, available_actions, goal.desired_state)
	if not success or leaves.is_empty():
		return []
		
	return _extract_optimal_plan(leaves)


## Recursive A* state-space graph builder.
static func _build_graph(parent: PlanNode, leaves: Array[PlanNode], usable_actions: Array[GOAPAction], goal_state: Dictionary) -> bool:
	var found_path := false
	
	for action: GOAPAction in usable_actions:
		if _are_conditions_met(action.preconditions, parent.state):
			var next_state := _apply_effects(parent.state, action.effects)
			var node := PlanNode.new(parent, parent.running_cost + action.cost, next_state, action)
			
			if _are_conditions_met(goal_state, next_state):
				leaves.append(node)
				found_path = true
			else:
				var remaining := usable_actions.duplicate()
				remaining.erase(action)
				
				if _build_graph(node, leaves, remaining, goal_state):
					found_path = true
					
	return found_path


static func _are_conditions_met(conditions: Dictionary, state: Dictionary) -> bool:
	if conditions.is_empty():
		return true
		
	for key: String in conditions.keys():
		if not state.has(key) or state[key] != conditions[key]:
			return false
	return true


static func _apply_effects(current_state: Dictionary, effects: Dictionary) -> Dictionary:
	var next_state := current_state.duplicate()
	for key: String in effects.keys():
		next_state[key] = effects[key]
	return next_state


static func _extract_optimal_plan(leaves: Array[PlanNode]) -> Array[GOAPAction]:
	var cheapest_node: PlanNode = null
	var lowest_cost: float = 999999.0
	
	for leaf: PlanNode in leaves:
		if leaf.running_cost < lowest_cost:
			lowest_cost = leaf.running_cost
			cheapest_node = leaf
			
	var compiled_plan: Array[GOAPAction] = []
	var current: PlanNode = cheapest_node
	
	while current != null and current.action != null:
		compiled_plan.insert(0, current.action)
		current = current.parent
		
	return compiled_plan
