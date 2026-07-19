# ==============================================================================
# Pathfile: res://src/Domain/Life/GOAP/GOAPPlanner.gd
# Description: Pure Domain mathematical solver for Goal-Oriented Action Planning.
#              Uses a specialized A* algorithm over an abstract state-space graph 
#              to find the lowest-cost sequence of actions to fulfill a Goal.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively executes the planning 
#   algorithm. It does not store state or execute actions.
# - Dependency Inversion Principle (DIP): Evaluates abstract GOAPAction and 
#   GOAPGoal interfaces polymorphically.
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
## Returns an array of GOAPAction instances (the Plan). Returns an empty array if no plan is found.
static func plan(goal: GOAPGoal, available_actions: Array[GOAPAction], initial_state: Dictionary) -> Array[GOAPAction]:
	var usable_actions: Array[GOAPAction] = _filter_usable_actions(available_actions)
	if usable_actions.is_empty():
		return []
		
	var leaves: Array[PlanNode] = []
	var start_node := PlanNode.new(null, 0.0, initial_state.duplicate(), null)
	
	var success := _build_graph(start_node, leaves, usable_actions, goal.desired_state)
	if not success or leaves.is_empty():
		return []
		
	return _extract_optimal_plan(leaves)


## Pre-filters actions to discard those that are not contextually valid (Optimization)
static func _filter_usable_actions(actions: Array[GOAPAction]) -> Array[GOAPAction]:
	var usable: Array[GOAPAction] = []
	# For planning purposes, we assume contextual validity if there's no blackboard context available,
	# as actual contextual validation happens at execution time. This filter can be expanded later.
	for action: GOAPAction in actions:
		usable.append(action)
	return usable


## Recursive A* state-space graph builder. Explores possible action combinations.
static func _build_graph(parent: PlanNode, leaves: Array[PlanNode], usable_actions: Array[GOAPAction], goal_state: Dictionary) -> bool:
	var found_path := false
	
	for action: GOAPAction in usable_actions:
		if _are_conditions_met(action.preconditions, parent.state):
			var new_state := _apply_effects(parent.state, action.effects)
			var node := PlanNode.new(parent, parent.running_cost + action.cost, new_state, action)
			
			if _are_conditions_met(goal_state, new_state):
				leaves.append(node)
				found_path = true
			else:
				var remaining_actions := usable_actions.duplicate()
				remaining_actions.erase(action)
				var sub_path_found := _build_graph(node, leaves, remaining_actions, goal_state)
				if sub_path_found:
					found_path = true
					
	return found_path


## Validates if all required conditions exist within the current simulated state
static func _are_conditions_met(conditions: Dictionary, state: Dictionary) -> bool:
	for key: String in conditions.keys():
		if not state.has(key):
			return false
		if state[key] != conditions[key]:
			return false
	return true


## Simulates the application of an action's effects onto the current state
static func _apply_effects(current_state: Dictionary, effects: Dictionary) -> Dictionary:
	var next_state := current_state.duplicate()
	for key: String in effects.keys():
		next_state[key] = effects[key]
	return next_state


## Evaluates all successful branches and returns the one with the lowest total cost
static func _extract_optimal_plan(leaves: Array[PlanNode]) -> Array[GOAPAction]:
	var cheapest_node: PlanNode = null
	var lowest_cost: float = 999999.0
	
	for leaf: PlanNode in leaves:
		if leaf.running_cost < lowest_cost:
			lowest_cost = leaf.running_cost
			cheapest_node = leaf
			
	var compiled_plan: Array[GOAPAction] = []
	var current: PlanNode = cheapest_node
	
	# Walk backwards up the tree to extract the actions
	while current != null and current.action != null:
		compiled_plan.insert(0, current.action) # Insert at beginning to reverse order
		current = current.parent
		
	return compiled_plan
