# ==============================================================================
# Pathfile: res://src/Domain/Life/CyberCitizenAIBehavior.gd
# Description: Specialized AI behavior strategy implementing robotic routines for
#              the Cyber Citizen Android NPC. Decomposed into short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CyberCitizenAIBehavior
extends IAIBehavior

const SPEED_PATROL: float = 1.1
const SCAN_INTERVAL_SEC: float = 4.0
const SCAN_DURATION_SEC: float = 1.6 

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# Decoupled metadata keys
const META_SCAN_TIMER := "cyber_scan_timer"
const META_ROT_STEP := "cyber_rot_step"
const META_WANDER_TIMER := "cyber_wander_timer"
const META_WANDER_DIR := "cyber_wander_dir"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives high-efficiency road pathing and robotic diagnostics
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	if host.get("is_talking") == true:
		_reset_cyber_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	
	if _process_security_sweep(host, delta):
		return
		
	var parent: Node = host.call("get_parent") as Node
	_process_highway_patrol(host, parent, delta)


func _process_security_sweep(host: Object, delta: float) -> bool:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai) or ai.get("current_task") as int != TASK_WORKING:
		return false
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0; velocity.z = 0.0
	host.set("velocity", velocity)
	
	var scan_timer: float = host.get_meta(META_SCAN_TIMER) as float
	scan_timer -= delta
	if scan_timer <= 0.0:
		_reset_cyber_state(host)
		return true
		
	var rot_step: int = host.get_meta(META_ROT_STEP) as int
	var new_step: int = floori((SCAN_DURATION_SEC - scan_timer) / 0.4)
	if new_step != rot_step:
		_execute_robotic_step_rotation(host, ai, new_step)
		
	host.set_meta(META_SCAN_TIMER, scan_timer)
	return true


func _execute_robotic_step_rotation(host: Object, ai: Object, new_step: int) -> void:
	host.set_meta(META_ROT_STEP, new_step)
	var angle: float = float(new_step) * (PI / 2.0)
	ai.set("wander_direction", Vector3(cos(angle), 0.0, sin(angle)))
	if host.has_method("_play_security_scan"):
		host.call("_play_security_scan")


func _process_highway_patrol(host: Object, parent: Node, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	var scan_timer: float = host.get_meta(META_SCAN_TIMER) as float
	scan_timer -= delta
	if scan_timer <= 0.0:
		host.set_meta(META_SCAN_TIMER, SCAN_DURATION_SEC)
		host.set_meta(META_ROT_STEP, 0)
		ai.set("current_task", TASK_WORKING)
		return
		
	host.set_meta(META_SCAN_TIMER, scan_timer)
	ai.set("current_task", TASK_WANDERING)
	_calculate_robotic_roaming(host, ai, parent, delta)


func _calculate_robotic_roaming(host: Object, _ai: Object, parent: Node, delta: float) -> void:
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var host_pos: Vector3 = host.get("global_position")
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 5.0)
		var road_vector := _scan_for_paved_roads(host_pos, parent)
		wander_dir = road_vector if road_vector != Vector3.ZERO else Vector3(cos(randf() * TAU), 0.0, sin(randf() * TAU))
		host.set_meta(META_WANDER_DIR, wander_dir)
		host.set_meta(META_WANDER_TIMER, wander_timer)
		
	_apply_computed_movement_vectors(host, wander_dir)


func _apply_computed_movement_vectors(host: Object, wander_dir: Vector3) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * SPEED_PATROL
		velocity.z = wander_dir.z * SPEED_PATROL
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_PATROL)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_PATROL)
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_SCAN_TIMER): host.set_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC)
	if not host.has_meta(META_ROT_STEP): host.set_meta(META_ROT_STEP, 0)
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)


func _reset_cyber_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC)
	host.set_meta(META_ROT_STEP, 0)
	host.set_meta(META_WANDER_TIMER, 1.0)


func _scan_for_paved_roads(host_pos: Vector3, world_node: Node) -> Vector3:
	if not is_instance_valid(world_node) or not "world_state" in world_node: return Vector3.ZERO
	var ws: WorldState = world_node.world_state
	if ws == null: return Vector3.ZERO
	
	var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
	for x in range(-2, 3):
		for z in range(-2, 3):
			var check_coord := my_coord + Vector3i(x, -1, z)
			if ws.get_block(check_coord) == 25: # 25 = Road
				var road_pos := Vector3(check_coord) + Vector3(0.5, 1.0, 0.5)
				var diff := road_pos - host_pos
				diff.y = 0.0
				if diff.length() > 0.8:
					return diff.normalized()
	return Vector3.ZERO
