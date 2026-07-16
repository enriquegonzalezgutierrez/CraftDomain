# ==============================================================================
# Pathfile: res://src/Domain/Life/AvianAIBehavior.gd
# Description: Pure Domain AI behavior strategy implementing state machine 
#              and decision logic for Avian Mobs (Birds and Parrots).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates AI state 
#   transitions, resting timers, and environmental scanning.
# - Layered DDD Compliance: Removed all direct physics velocity writes (no framework leakage),
#   keeping the Domain layer strictly focused on pure logical states.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AvianAIBehavior
extends IAIBehavior

const PERCH_DURATION_SEC: float = 5.0

# Decoupled task states
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Flight State machine: 0 = SOARING, 1 = LANDING_TO_PERCH, 2 = PERCHED
const STATE_SOARING = 0
const STATE_LANDING = 1
const STATE_PERCHED = 2

# Decoupled metadata keys
const META_STATE := "avian_flight_state"
const META_WANDER_TIMER := "avian_wander_timer"
const META_WANDER_DIR := "avian_wander_dir"
const META_TARGET_LEAF := "avian_leaf_target"
const META_REST_TIMER := "avian_rest_timer"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives logical flight states, landing checks, and perched rests
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	_evaluate_panic_takeoff(host)
	
	var state: int = host.get_meta(META_STATE) as int
	match state:
		STATE_PERCHED:
			_process_perched_state(host, delta)
		STATE_LANDING:
			_process_landing_state(host)
		STATE_SOARING:
			_process_soaring_state(host, delta)


func _evaluate_panic_takeoff(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai) and ai.get("current_task") as int == TASK_PANIC:
		var state: int = host.get_meta(META_STATE) as int
		if state == STATE_PERCHED:
			# Force immediate takeoff during panic
			host.set_meta(META_STATE, STATE_SOARING)
			host.set_meta(META_TARGET_LEAF, Vector3i(0, -999, 0))


func _process_perched_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): 
		return
	
	ai.set("current_task", TASK_IDLE)
	ai.set("wander_direction", Vector3.ZERO)
	
	var rest_timer: float = host.get_meta(META_REST_TIMER) as float
	rest_timer -= delta
	
	if rest_timer <= 0.0:
		# Return to soaring flight after resting period expires
		host.set_meta(META_STATE, STATE_SOARING)
		host.set_meta(META_TARGET_LEAF, Vector3i(0, -999, 0))
	else:
		host.set_meta(META_REST_TIMER, rest_timer)


func _process_landing_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_WORKING)


func _process_soaring_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): 
		return
	
	var is_panicking := ai.get("current_task") as int == TASK_PANIC
	ai.set("current_task", TASK_PANIC if is_panicking else TASK_WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	wander_timer -= delta
	
	if wander_timer <= 0.0:
		_handle_soaring_timer_timeout(host, is_panicking)
		wander_timer = randf_range(3.0, 6.0)
		
	host.set_meta(META_WANDER_TIMER, wander_timer)


func _handle_soaring_timer_timeout(host: Object, is_panicking: bool) -> void:
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	
	if ws != null and not is_panicking and randf() < 0.35:
		var host_pos: Vector3 = host.get("global_position") as Vector3
		var leaves_coord := _scan_for_nest_leaves(host_pos, ws)
		
		if leaves_coord.y != -999:
			host.set_meta(META_STATE, STATE_LANDING)
			host.set_meta(META_TARGET_LEAF, leaves_coord)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_STATE): host.set_meta(META_STATE, STATE_SOARING)
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_TARGET_LEAF): host.set_meta(META_TARGET_LEAF, Vector3i(0, -999, 0))
	if not host.has_meta(META_REST_TIMER): host.set_meta(META_REST_TIMER, 0.0)


func _scan_for_nest_leaves(host_pos: Vector3, ws: WorldState) -> Vector3i:
	var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
	for x in range(-5, 6):
		for y in range(-4, 5):
			for z in range(-5, 6):
				var check_coord := my_coord + Vector3i(x, y, z)
				if ws.get_block(check_coord) == 5: # 5 = Leaves Block
					if ws.get_block(check_coord + Vector3i(0, 1, 0)) == 0: # 0 = Air
						return check_coord
	return Vector3i(0, -999, 0)
