# ==============================================================================
# Pathfile: res://src/Domain/Life/MerchantAIBehavior.gd
# Description: Specialized AI behavior strategy implementing mercantile routines for
#              the Village Merchant. Decomposed into short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MerchantAIBehavior
extends IAIBehavior

const SPEED_PATROL: float = 1.0
const SPEED_RETREAT: float = 1.6
const COOLDOWN_COINS_SEC: float = 2.5

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# Decoupled metadata keys
const META_WANDER_TIMER := "merchant_wander_timer"
const META_WANDER_DIR := "merchant_wander_dir"
const META_COOLDOWN := "merchant_gold_cooldown"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives daily sales, night retreats, and gold counting cycles
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	if host.get("is_talking") == true:
		_reset_merchant_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	_update_gold_cooldown(host, delta)
	
	var parent: Node = host.call("get_parent") as Node
	
	if _process_nighttime_accounting(host, parent, delta):
		return
		
	_process_daytime_business(host, delta)


func _update_gold_cooldown(host: Object, delta: float) -> void:
	var gold_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if gold_cooldown > 0.0:
		gold_cooldown -= delta
		host.set_meta(META_COOLDOWN, gold_cooldown)


func _process_nighttime_accounting(host: Object, parent: Node, _delta: float) -> bool:
	var is_night := CelestialService.is_night_time_static()
	if not is_night:
		return false
		
	var host_pos: Vector3 = host.get("global_position")
	var nav_service: Object = parent.get("navigation_service") if is_instance_valid(parent) else null
	
	if _is_inside_shelter(host_pos, nav_service):
		_execute_accounting_shimmers(host)
	else:
		_route_nighttime_retreat(host, nav_service, host_pos)
		
	return true


func _is_inside_shelter(host_pos: Vector3, nav_service: Object) -> bool:
	if is_instance_valid(nav_service) and "_indoor_nodes" in nav_service:
		var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
		var indoor_nodes: Array = nav_service.get("_indoor_nodes") as Array
		return indoor_nodes.has(my_coord)
	return false


func _execute_accounting_shimmers(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.BACK)
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0; velocity.z = 0.0
	host.set("velocity", velocity)
	
	var gold_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if gold_cooldown <= 0.0:
		host.set_meta(META_COOLDOWN, COOLDOWN_COINS_SEC)
		if host.has_method("_play_counting_coins"):
			host.call("_play_counting_coins")


func _route_nighttime_retreat(host: Object, nav_service: Object, host_pos: Vector3) -> void:
	if is_instance_valid(nav_service) and nav_service.has_method("find_closest_shelter_node"):
		var shelter_pos: Vector3 = nav_service.call("find_closest_shelter_node", host_pos)
		if shelter_pos != Vector3.ZERO:
			var diff := shelter_pos - host_pos
			diff.y = 0.0
			if diff.length() > 0.8:
				var retreat_dir := diff.normalized()
				var velocity: Vector3 = host.get("velocity") as Vector3
				velocity.x = retreat_dir.x * SPEED_RETREAT
				velocity.z = retreat_dir.z * SPEED_RETREAT
				host.set("velocity", velocity)
				
				var ai: Object = host.get("ai_component")
				if is_instance_valid(ai):
					ai.set("wander_direction", retreat_dir)
					ai.set("current_task", TASK_WANDERING)


func _process_daytime_business(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	ai.set("current_task", TASK_WORKING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var host_pos: Vector3 = host.get("global_position")
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		var spawn_point: Vector3 = host.get("_spawn_point") as Vector3
		if host_pos.distance_to(spawn_point) > 5.0:
			wander_dir = (spawn_point - host_pos).normalized()
			wander_dir.y = 0.0
		else:
			wander_dir = Vector3(cos(randf() * TAU), 0.0, sin(randf() * TAU)) if randf() < 0.4 else Vector3.ZERO
			
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
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 0.0)


func _reset_merchant_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_WANDER_TIMER, 1.0)
