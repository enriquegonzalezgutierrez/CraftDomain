# ==============================================================================
# Pathfile: res://src/Domain/Life/CanineAIBehavior.gd
# Description: Specialized AI behavior strategy implementing loyal canine routines
#              for the Fiery Growlithe dog. Decomposed into short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CanineAIBehavior
extends IAIBehavior

const SPEED_WALK: float = 1.0
const SPEED_TROT: float = 1.6
const COOLDOWN_BARK_SEC: float = 4.0

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_WANDER_TIMER := "growlithe_wander_timer"
const META_WANDER_DIR := "growlithe_wander_dir"
const META_BARK_COOLDOWN := "growlithe_bark_cooldown"
const META_TARGET_LAVA := "growlithe_lava_target"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives lava tracking, magma sniffing, and flame barking cycles
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	_update_bark_cooldown(host, delta)
	
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	
	var is_tracking_lava := false
	if ws != null:
		is_tracking_lava = _process_lava_tracking(host, ws, delta)
		
	if not is_tracking_lava:
		_process_playful_wandering(host, delta)


func _update_bark_cooldown(host: Object, delta: float) -> void:
	var bark_cooldown: float = host.get_meta(META_BARK_COOLDOWN) as float
	if bark_cooldown > 0.0:
		bark_cooldown -= delta
		host.set_meta(META_BARK_COOLDOWN, bark_cooldown)


func _process_lava_tracking(host: Object, ws: WorldState, _delta: float) -> bool:
	var target_lava: Vector3i = host.get_meta(META_TARGET_LAVA) as Vector3i
	if target_lava.y == -999:
		target_lava = _scan_for_nearby_lava(host.global_position, ws)
		host.set_meta(META_TARGET_LAVA, target_lava)
		
	if target_lava.y == -999:
		return false
		
	var ai: Object = host.get("ai_component")
	var host_node := host as Node3D
	if not is_instance_valid(ai) or not is_instance_valid(host_node): return false
	
	ai.set("current_task", TASK_WORKING)
	var lava_pos := Vector3(target_lava) + Vector3(0.5, 0.0, 0.5)
	var diff: Vector3 = lava_pos - host_node.global_position
	diff.y = 0.0
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if diff.length() > 2.0:
		var trot_dir: Vector3 = diff.normalized()
		velocity.x = trot_dir.x * SPEED_TROT
		velocity.z = trot_dir.z * SPEED_TROT
		host.set("velocity", velocity)
		ai.set("wander_direction", trot_dir)
	else:
		velocity.x = 0.0; velocity.z = 0.0
		host.set("velocity", velocity)
		ai.set("wander_direction", diff.normalized())
		_execute_fire_bark(host)
		
	return true


func _execute_fire_bark(host: Object) -> void:
	var bark_cooldown: float = host.get_meta(META_BARK_COOLDOWN) as float
	if bark_cooldown <= 0.0:
		host.set_meta(META_BARK_COOLDOWN, COOLDOWN_BARK_SEC)
		if host.has_method("_play_flame_bark"):
			host.call("_play_flame_bark")


func _process_playful_wandering(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	ai.set("current_task", TASK_WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		var roll := randf()
		if roll < 0.4:
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
			wander_timer = randf_range(1.5, 4.0)
		elif roll < 0.65:
			# Playful tail chasing: force spin velocity
			var angle: float = float(Time.get_ticks_msec() / 100.0)
			wander_dir = Vector3(cos(angle), 0.0, sin(angle)).normalized()
			wander_timer = 1.5 
		else:
			wander_dir = Vector3.ZERO
			wander_timer = randf_range(1.5, 4.0)
			
		host.set_meta(META_WANDER_DIR, wander_dir)
		host.set_meta(META_WANDER_TIMER, wander_timer)
		
	_apply_computed_movement_vectors(host, wander_dir)


func _apply_computed_movement_vectors(host: Object, wander_dir: Vector3) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * SPEED_WALK
		velocity.z = wander_dir.z * SPEED_WALK
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_WALK)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_WALK)
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_BARK_COOLDOWN): host.set_meta(META_BARK_COOLDOWN, 0.0)
	if not host.has_meta(META_TARGET_LAVA): host.set_meta(META_TARGET_LAVA, Vector3i(0, -999, 0))


func _scan_for_nearby_lava(host_pos: Vector3, ws: WorldState) -> Vector3i:
	var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
	for x in range(-5, 6):
		for y in range(-2, 3):
			for z in range(-5, 6):
				var check_coord := my_coord + Vector3i(x, y, z)
				if ws.get_block(check_coord) == 15: # 15 = Lava
					return check_coord
	return Vector3i(0, -999, 0)
