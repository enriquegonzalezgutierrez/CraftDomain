# ==============================================================================
# Pathfile: res://src/Domain/Life/FaunaAIBehavior.gd
# Description: Pure Domain Strategy implementing generic wildlife behaviors,
#              grazing, and high-frequency panic evasions.
#              Decomposed into single-responsibility short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FaunaAIBehavior
extends IAIBehavior

const SPEED_PANIC: float = 2.5
const SPEED_GRAZE: float = 0.8
const SENSORY_RANGE_SQ: float = 64.0 # 8.0 meters squared threat detection

# Decoupled task states mirroring presentation layers
const TASK_WANDERING = 1
const TASK_PANIC = 5

# Decoupled metadata keys
const META_WANDER_TIMER := "fauna_wander_timer"
const META_WANDER_DIR := "fauna_wander_dir"
const META_PANIC_TIMER := "fauna_panic_timer"
const META_STUCK_TIMER := "fauna_stuck_timer"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Coordinates active physical escape vs peaceful grazing states
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var panic_timer: float = host.get_meta(META_PANIC_TIMER) as float
	var is_panicking := panic_timer > 0.0
	
	if is_panicking:
		panic_timer -= delta
		host.set_meta(META_PANIC_TIMER, panic_timer)
		is_panicking = panic_timer > 0.0
		
	if not is_panicking:
		is_panicking = _check_threat_proximity(host)
		
	if is_panicking:
		_process_panic_escape(host, delta)
	else:
		_process_peaceful_grazing(host, delta)
		
	_apply_computed_movement_vectors(host)


func _check_threat_proximity(host: Object) -> bool:
	var closest_threat := _scan_for_hostile_monsters(host)
	if closest_threat != null:
		var host_pos: Vector3 = host.get("global_position")
		var threat_pos: Vector3 = closest_threat.get("global_position")
		var escape_dir := (host_pos - threat_pos).normalized()
		escape_dir.y = 0.0
		
		host.set_meta(META_PANIC_TIMER, 4.5) # Enter panic state for 4.5s
		host.set_meta(META_WANDER_DIR, escape_dir)
		return true
	return false


func _process_panic_escape(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	ai.set("current_task", TASK_PANIC)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(0.3, 0.8) # Frantic directional changes
		var angle := randf() * TAU
		var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
		if _is_direction_safe_fauna(host, candidate_dir):
			host.set_meta(META_WANDER_DIR, candidate_dir)
			
	host.set_meta(META_WANDER_TIMER, wander_timer)


func _process_peaceful_grazing(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	ai.set("current_task", TASK_WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		if randf() < 0.45:
			var angle := randf() * TAU
			var target_dir := Vector3(cos(angle), 0.0, sin(angle))
			wander_dir = target_dir if _is_direction_safe_fauna(host, target_dir) else Vector3.ZERO
			wander_timer = randf_range(2.0, 5.0)
		else:
			wander_dir = Vector3.ZERO
			wander_timer = randf_range(1.5, 4.0)
			
		host.set_meta(META_WANDER_DIR, wander_dir)
		
	host.set_meta(META_WANDER_TIMER, wander_timer)
	_check_and_resolve_wall_collisions(host, wander_dir, delta)


func _check_and_resolve_wall_collisions(host: Object, wander_dir: Vector3, delta: float) -> void:
	var stuck_timer: float = host.get_meta(META_STUCK_TIMER) as float
	if wander_dir != Vector3.ZERO and host.call("is_on_wall"):
		stuck_timer += delta
		if stuck_timer > 0.4:
			stuck_timer = 0.0
			var wall_normal: Vector3 = host.call("get_wall_normal")
			var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
			if flat_normal != Vector3.ZERO:
				var bounce_dir := wander_dir.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.3, 0.3)).normalized()
				host.set_meta(META_WANDER_DIR, bounce_dir)
	else:
		stuck_timer = 0.0
	host.set_meta(META_STUCK_TIMER, stuck_timer)


func _apply_computed_movement_vectors(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	var velocity: Vector3 = host.get("velocity")
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var panic_timer: float = host.get_meta(META_PANIC_TIMER) as float
	var is_panicking := panic_timer > 0.0
	
	if wander_dir != Vector3.ZERO:
		var speed := SPEED_PANIC if is_panicking else SPEED_GRAZE
		velocity.x = wander_dir.x * speed
		velocity.z = wander_dir.z * speed
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_GRAZE)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_GRAZE)
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_PANIC_TIMER): host.set_meta(META_PANIC_TIMER, 0.0)
	if not host.has_meta(META_STUCK_TIMER): host.set_meta(META_STUCK_TIMER, 0.0)


func _scan_for_hostile_monsters(host: Object) -> Object:
	var closest_threat: Object = null
	var min_dist_sq := SENSORY_RANGE_SQ
	var hostiles: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			hostiles = tree.call("get_nodes_in_group", "hostiles")
			
	var host_pos: Vector3 = host.get("global_position")
	for child: Object in hostiles:
		if is_instance_valid(child):
			var zombie_domain: Object = child.get("domain_entity")
			if zombie_domain != null and not zombie_domain.get("is_dead"):
				var child_pos: Vector3 = child.get("global_position")
				var dist_sq := host_pos.distance_squared_to(child_pos)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_threat = child
	return closest_threat


func _is_direction_safe_fauna(host: Object, dir: Vector3) -> bool:
	var world_node: Node = host.call("get_parent") as Node if host.has_method("get_parent") else null
	if not is_instance_valid(world_node) or not "world_state" in world_node: return true
	var ws: WorldState = world_node.world_state
	if ws == null: return true
	
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 1.5
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	var block_below := ws.get_block(block_below_coord)
	var block_at := ws.get_block(block_at_coord)
	
	if BlockType.is_solid(block_at): return false
	
	var habitat: int = host.call("_get_habitat") as int if host.has_method("_get_habitat") else 0
	if habitat == 2: # AQUATIC
		return block_below == 6 or block_at == 6
	elif habitat == 1: # AMPHIBIOUS
		return block_below == 6 or block_at == 6 or block_below == 7 or block_below == 11
	else: # TERRESTRIAL
		var is_liquid := block_below == 6 or block_below == 15 or block_at == 6
		var is_void := block_below == 0
		if is_void:
			var block_2_below := ws.get_block(block_below_coord + Vector3i(0, -1, 0))
			if block_2_below != 0 and block_2_below != 6 and block_2_below != 15: is_void = false
		return not is_liquid and not is_void
