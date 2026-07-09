# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: AmphibiousAIBehavior
# Description: Specialized AI behavior strategy implementing the movement loop
#              for amphibious fauna (Sea Turtles and Crabs). It calculates 
#              surrounding voxel types in real-time, executing smooth fluid 
#              buoyancy oscillations when swimming in Water and applying heavy 
#              crawling speed dampening when traversing sandy shores.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates the 
#   amphibious decision trees, speed switches, and marine boundaries of the entity.
# - Liskov Substitution Principle (LSP): Fully compatible with the IAIBehavior 
#   contract signatures, resolving old hardcoded string checks in FaunaAI.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/AmphibiousAIBehavior.gd
# ==============================================================================
class_name AmphibiousAIBehavior
extends IAIBehavior

const SPEED_CRAWL: float = 0.4
const SPEED_SWIM: float = 1.1
const SPEED_PANIC_MULTIPLIER: float = 2.5

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_WANDERING = 1
const TASK_PANIC = 5

# Decoupled metadata keys to store state variables safely on the host node
const META_WANDER_TIMER := "amphibious_wander_timer"
const META_WANDER_DIR := "amphibious_wander_dir"
const META_PANIC_TIMER := "amphibious_panic_timer"


func _init() -> void:
	# Amphibious entities completely override standard wander schedules
	overrides_wandering = true


## Concrete Contract: Drives the amphibious swimming and crawling logic
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var panic_timer: float = host.get_meta(META_PANIC_TIMER) as float
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity")
	var host_pos: Vector3 = host.get("global_position")
	
	# Determine panic conditions
	var is_panicking := false
	if panic_timer > 0.0:
		panic_timer -= delta
		host.set_meta(META_PANIC_TIMER, panic_timer)
		is_panicking = true

	# ==========================================================================
	# 1. ENVIROMENT MATERIAL DETECTION (Water vs Land/Shore)
	# ==========================================================================
	var is_in_water := false
	var world_node: Node = null
	if host.has_method("get_parent"):
		world_node = host.call("get_parent") as Node
		
	if is_instance_valid(world_node) and "world_state" in world_node:
		var ws: WorldState = world_node.get("world_state") as WorldState
		if ws != null:
			var block_at_feet := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
			var block_below_feet := Vector3i(floori(host_pos.x), floori(host_pos.y - 0.5), floori(host_pos.z))
			
			# Block ID 6 is WaterBlock (WATER)
			is_in_water = (ws.get_block(block_at_feet) == 6 or ws.get_block(block_below_feet) == 6)

	# ==========================================================================
	# 2. DECISION PATH ENGINE (Restricted strictly to Coastline & Ocean)
	# ==========================================================================
	ai.set("current_task", TASK_PANIC if is_panicking else TASK_WANDERING)
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		if is_panicking:
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
		else:
			# Grazing resting check: 50% chance to roam, 50% to sleep/graze
			if randf() < 0.5:
				var angle := randf() * TAU
				var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
				
				# Scan boundaries before stepping to avoid leaving shores
				if _is_direction_safe_amphibious(host, candidate_dir, world_node):
					wander_dir = candidate_dir
				else:
					wander_dir = Vector3.ZERO
			else:
				wander_dir = Vector3.ZERO
				
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)

	# ==========================================================================
	# 3. COORDINATES AND BUOYANCY VECTOR CALCULATIONS
	# ==========================================================================
	if wander_dir != Vector3.ZERO:
		var speed: float = SPEED_SWIM if is_in_water else SPEED_CRAWL
		if is_panicking:
			speed *= SPEED_PANIC_MULTIPLIER
			
		velocity.x = wander_dir.x * speed
		velocity.z = wander_dir.z * speed
		
		# Symmetrical Buoyancy oscillation when swimming in water
		if is_in_water:
			var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
			velocity.y = sin(time_sec * 2.0) * 0.15 # Smooth vertical sinusoidal swim
		
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_SWIM)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_SWIM)
		
		# Symmetrical rest hovering in currents
		if is_in_water:
			var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
			velocity.y = sin(time_sec * 1.5) * 0.08
			
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_PANIC_TIMER):
		host.set_meta(META_PANIC_TIMER, 0.0)


## Boundary Sensor: Constrains amphibious movement strictly to Water, Sand, and Mud.
func _is_direction_safe_amphibious(host: Object, dir: Vector3, world_node: Node) -> bool:
	if not is_instance_valid(world_node) or not "world_state" in world_node:
		return true
		
	var ws: WorldState = world_node.get("world_state") as WorldState
	if ws == null:
		return true
		
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 1.5
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	var block_below: int = ws.get_block(block_below_coord)
	var block_at: int = ws.get_block(block_at_coord)
	
	# Allowed block mappings: WATER = 6, SAND = 7, MUD = 11
	var is_water: bool = (block_below == 6 or block_at == 6)
	var is_shore: bool = (block_below == 7 or block_below == 11)
	
	return is_water or is_shore
