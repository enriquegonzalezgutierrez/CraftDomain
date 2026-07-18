# ==============================================================================
# Pathfile: res://src/Domain/World/AmphibiousAIBehavior.gd
# Description: Specialized AI behavior strategy implementing organic swimming
#              and shore crawling for amphibious fauna (Turtles & Crabs) (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AmphibiousAIBehavior
extends IAIBehavior

const SPEED_CRAWL: float = 0.4
const SPEED_SWIM: float = 1.1
const SPEED_PANIC_MULTIPLIER: float = 2.5

const TASK_WANDERING = 1
const TASK_PANIC = 5

const META_WANDER_TIMER := "amphibious_wander_timer"
const META_WANDER_DIR := "amphibious_wander_dir"
const META_PANIC_TIMER := "amphibious_panic_timer"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Coordinates coastal crawling and fluid swimming (SRP Decomposed)
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	var host_pos: Vector3 = host.get("global_position")
	var is_panicking := _process_panic_state(host, delta)
	var is_in_water := _detect_water_state(host, host_pos)
	
	ai.set("current_task", TASK_PANIC if is_panicking else TASK_WANDERING)
	
	var wander_dir := _update_decision_path_engine(host, ai, delta, is_panicking)
	_apply_hydrodynamic_locomotion(host, ai, wander_dir, is_in_water, is_panicking)


func _process_panic_state(host: Object, delta: float) -> bool:
	var panic_timer: float = host.get_meta(META_PANIC_TIMER) as float
	if panic_timer > 0.0:
		panic_timer -= delta
		host.set_meta(META_PANIC_TIMER, panic_timer)
		return true
	return false


func _detect_water_state(host: Object, host_pos: Vector3) -> bool:
	var world_node: Node = host.call("get_parent") as Node if host.has_method("get_parent") else null
	if is_instance_valid(world_node) and "world_state" in world_node:
		var ws: WorldState = world_node.world_state
		if ws != null:
			var feet := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
			var below := Vector3i(floori(host_pos.x), floori(host_pos.y - 0.5), floori(host_pos.z))
			return ws.get_block(feet) == 6 or ws.get_block(below) == 6
	return false


func _update_decision_path_engine(host: Object, ai: Object, delta: float, is_panicking: bool) -> Vector3:
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		var world_node: Node = host.call("get_parent") as Node if host.has_method("get_parent") else null
		
		if is_panicking:
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
		elif randf() < 0.5:
			var angle := randf() * TAU
			var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
			wander_dir = candidate_dir if _is_direction_safe_amphibious(host, candidate_dir, world_node) else Vector3.ZERO
		else:
			wander_dir = Vector3.ZERO
			
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)
		
	return wander_dir


func _apply_hydrodynamic_locomotion(host: Object, ai: Object, wander_dir: Vector3, is_in_water: bool, is_panicking: bool) -> void:
	var velocity: Vector3 = host.get("velocity") as Vector3
	var in_liquid: bool = host.call("is_in_liquid") as bool if host.has_method("is_in_liquid") else true
	
	if wander_dir != Vector3.ZERO:
		var speed := SPEED_SWIM if is_in_water else SPEED_CRAWL
		if is_panicking: speed *= SPEED_PANIC_MULTIPLIER
			
		velocity.x = wander_dir.x * speed
		velocity.z = wander_dir.z * speed
		if is_in_water and in_liquid:
			velocity.y = sin(float(Time.get_ticks_msec()) / 1000.0 * 2.0) * 0.15 
			
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_SWIM)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_SWIM)
		if is_in_water and in_liquid:
			velocity.y = sin(float(Time.get_ticks_msec()) / 1000.0 * 1.5) * 0.08
			
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_PANIC_TIMER): host.set_meta(META_PANIC_TIMER, 0.0)


func _is_direction_safe_amphibious(host: Object, dir: Vector3, world_node: Node) -> bool:
	if not is_instance_valid(world_node) or not "world_state" in world_node: return true
	var ws: WorldState = world_node.world_state
	if ws == null: return true
	
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 1.5
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	var block_below: int = ws.get_block(block_below_coord)
	var block_at: int = ws.get_block(block_at_coord)
	
	return block_below == 6 or block_at == 6 or block_below == 7 or block_below == 11
