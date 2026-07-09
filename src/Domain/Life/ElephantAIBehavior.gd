# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: ElephantAIBehavior
# Description: Specialized AI behavior strategy implementing heavy colossal routines
#              for the Colossal Elephant. It features slow, massive walk cycles 
#              and coordinates stride timers: every time a stride completes, 
#              it calls a heavy stone-impact stomp on the host to trigger 
#              localized screen shake and deep ground thuds for near players.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates solely the stride timing
#   and ponderous movement directions of the elephant, keeping screen-shake 
#   renderers decoupled.
# - Liskov Substitution Principle (LSP): Fully compatible with the contract signatures.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/ElephantAIBehavior.gd
# ==============================================================================
class_name ElephantAIBehavior
extends IAIBehavior

const SPEED_WALK: float = 0.6
const STRIDE_INTERVAL_SEC: float = 1.8

const RANGE_SIGHT_SQ: float = 144.0 # 12.0 meters squared player shake radius

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5

# Decoupled metadata keys to store state variables safely on the host node
const META_WANDER_TIMER := "elephant_wander_timer"
const META_WANDER_DIR := "elephant_wander_dir"
const META_STRIDE_TIMER := "elephant_stride_timer"


func _init() -> void:
	# Elephants completely override standard schedules to walk slowly
	overrides_wandering = true


## Concrete Contract: Drives heavy walk strides, rest, and stomp triggers
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var stride_timer: float = host.get_meta(META_STRIDE_TIMER) as float
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	var parent: Node = host.call("get_parent") as Node

	# Check panic/startle state
	var is_panicking := false
	if ai.get("current_task") as int == TASK_PANIC:
		is_panicking = true

	# ==========================================================================
	# 1. PONDEROUS WALKING STATE
	# ==========================================================================
	ai.set("current_task", TASK_PANIC if is_panicking else TASK_WANDERING)
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		# Stride decision: 45% chance to stroll, 55% chance to rest/eat shrubs
		var roll := randf()
		if roll < 0.45:
			var angle := randf() * TAU
			var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
			
			if _is_direction_safe_elephant(host, candidate_dir, parent):
				wander_dir = candidate_dir
			else:
				wander_dir = Vector3.ZERO
			wander_timer = randf_range(4.0, 8.0) # Long walk cycles
		else:
			wander_dir = Vector3.ZERO
			wander_timer = randf_range(2.0, 5.0) # Long rest phases
			
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)

	# ==========================================================================
	# 2. STRIDE PROGRESSION & HEAVY GROUND STOMP TRIGGERS
	# ==========================================================================
	if wander_dir != Vector3.ZERO:
		var speed: float = SPEED_WALK * (1.6 if is_panicking else 1.0)
		velocity.x = wander_dir.x * speed
		velocity.z = wander_dir.z * speed
		
		# Decrement stride clock during locomotion
		stride_timer -= delta
		if stride_timer <= 0.0:
			stride_timer = STRIDE_INTERVAL_SEC
			
			# STEP TRIGGERED! Call heavy stomp impact on physical presenter
			if host.has_method("_play_heavy_step_impact"):
				host.call("_play_heavy_step_impact")
				
		host.set_meta(META_STRIDE_TIMER, stride_timer)
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_WALK)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_WALK)
		
		# Reset stride timer so the next first step triggers stomp instantly
		stride_timer = 0.4
		host.set_meta(META_STRIDE_TIMER, stride_timer)
		
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_STRIDE_TIMER):
		host.set_meta(META_STRIDE_TIMER, 0.4)


## Safe Check: Keeps the elephant safe from drowning or falling off canyon cliffs
func _is_direction_safe_elephant(host: Object, dir: Vector3, world_node: Node) -> bool:
	if not is_instance_valid(world_node) or not "world_state" in world_node:
		return true
		
	var ws: WorldState = world_node.get("world_state") as WorldState
	if ws == null:
		return true
		
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 2.5 # Check further ahead due to its massive size
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	var block_below: int = ws.get_block(block_below_coord)
	var block_at: int = ws.get_block(block_at_coord)
	
	# Solid checks: strictly avoid deep water reservoirs (6) or empty void drops (0)
	var is_water: bool = (block_below == 6 or block_at == 6)
	var is_void: bool = (block_below == 0)
	
	return not is_water and not is_void
