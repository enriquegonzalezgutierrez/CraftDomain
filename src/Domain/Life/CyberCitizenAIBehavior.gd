# ==============================================================================
# Pathfile: res://src/Domain/Life/CyberCitizenAIBehavior.gd
# Description: Specialized AI behavior strategy implementing robotic routines for
#              the Cyber Citizen Android NPC.
#              UPGRADE: Implemented Localized State Machine, Defensive Retreat,
#              and Terminal Data Uploading.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly robotic highway 
#   pathing, security sweeps, and data uploading. All methods kept strictly < 20 lines.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior, closing core physical
#   movement nodes to direct modifications.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CyberCitizenAIBehavior
extends IAIBehavior

# Localized State Machine (SRP / OCP Compliant)
enum State {
	PATROLLING,   # Walking along the paved highway roads
	SCANNING,     # Performing 360-degree security scans and laser sweeps
	UPLOADING,    # Channeling data upload near Neon Magenta terminals
	FLEEING       # Executing defensive tactical retreat from threat vectors
}

const SPEED_PATROL: float = 1.1
const SPEED_RETREAT: float = 1.6

const SCAN_INTERVAL_SEC: float = 4.0
const SCAN_DURATION_SEC: float = 1.6 
const UPLOAD_INTERVAL_SEC: float = 15.0
const UPLOAD_DURATION_SEC: float = 3.0

const SENSORY_RANGE_SQ: float = 100.0  # 10.0m scanning radius

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_STATE := "cyber_local_state"
const META_SCAN_TIMER := "cyber_scan_timer"
const META_ROT_STEP := "cyber_rot_step"
const META_WANDER_TIMER := "cyber_wander_timer"
const META_WANDER_DIR := "cyber_wander_dir"
const META_UPLOAD_COOLDOWN := "cyber_upload_cooldown"
const META_UPLOAD_TIMER := "cyber_upload_timer"


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
	_update_timers(host, delta)
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	# Priority 1: Defensive retreat (Keep distance from threats)
	if _process_defensive_panic(host, ai, delta):
		return
		
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	
	# Priority 2: Terminals uploading (Terminal data transmission)
	if ws != null and _process_data_upload(host, ai, ws, delta):
		return
		
	# Priority 3: Security sweeping (360 degrees scan)
	if _process_security_sweep(host, ai, delta):
		return
		
	# Priority 4: Highway patrolling
	_process_highway_patrol(host, ai, parent, delta)


func _update_timers(host: Object, delta: float) -> void:
	var upload_cd := host.get_meta(META_UPLOAD_COOLDOWN) as float
	if upload_cd > 0.0:
		host.set_meta(META_UPLOAD_COOLDOWN, upload_cd - delta)


# ==============================================================================
# DEFENSIVE PANIC RETREAT
# ==============================================================================

func _process_defensive_panic(host: Object, ai: Object, delta: float) -> bool:
	var is_panicking := ai.get("current_task") as int == TASK_PANIC
	if not is_panicking and _detect_threat_proximity(host):
		is_panicking = true
		ai.set("current_task", TASK_PANIC)
		
	if not is_panicking:
		return false
		
	host.set_meta(META_STATE, State.FLEEING)
	_execute_tactical_flee(host, ai, delta)
	return true


func _execute_tactical_flee(host: Object, ai: Object, delta: float) -> void:
	var wander_timer := host.get_meta(META_WANDER_TIMER) as float
	var wander_dir := host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(0.5, 1.0)
		var threat := _scan_for_closest_threat(host)
		if is_instance_valid(threat):
			# STRICT TYPING FIX: Cast Variant explicitly to Vector3 before subtraction
			var host_pos: Vector3 = host.get("global_position")
			wander_dir = (host_pos - threat.global_position).normalized()
			wander_dir.y = 0.0
		else:
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
			
	host.set_meta(META_WANDER_TIMER, wander_timer)
	host.set_meta(META_WANDER_DIR, wander_dir)
	_apply_movement_vectors(host, ai, wander_dir, SPEED_RETREAT)


func _detect_threat_proximity(host: Object) -> bool:
	if not host.call("is_inside_tree"): return false
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
				var dist_sq := host_pos.distance_squared_to(child.get("global_position"))
				if dist_sq <= SENSORY_RANGE_SQ:
					return true
	return false


func _scan_for_closest_threat(host: Object) -> Node3D:
	if not host.call("is_inside_tree"): return null
	var hostiles: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			hostiles = tree.call("get_nodes_in_group", "hostiles")
			
	var host_pos: Vector3 = host.get("global_position")
	var closest_threat: Node3D = null
	var min_dist_sq := SENSORY_RANGE_SQ
	
	for child: Object in hostiles:
		if is_instance_valid(child) and child is Node3D:
			var domain: Object = child.get("domain_entity")
			if domain != null and not domain.get("is_dead"):
				var dist_sq := host_pos.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_threat = child as Node3D
	return closest_threat


# ==============================================================================
# DATA TERMINALS UPLOADING
# ==============================================================================

func _process_data_upload(host: Object, ai: Object, ws: WorldState, delta: float) -> bool:
	var upload_cd := host.get_meta(META_UPLOAD_COOLDOWN) as float
	if upload_cd > 0.0:
		return false
		
	var host_pos: Vector3 = host.get("global_position")
	var terminal_coord := _scan_for_nearby_terminal(host_pos, ws)
	if terminal_coord.y == -999:
		return false
		
	host.set_meta(META_STATE, State.UPLOADING)
	ai.set("current_task", TASK_WORKING)
	_halt_movement(host, ai)
	
	_execute_upload_channel(host, ai, terminal_coord, delta)
	return true


func _execute_upload_channel(host: Object, ai: Object, terminal_coord: Vector3i, delta: float) -> void:
	var term_pos := Vector3(terminal_coord) + Vector3(0.5, 0.5, 0.5)
	
	# STRICT TYPING FIX: Cast Variant explicitly to Vector3 before subtraction
	var host_pos: Vector3 = host.get("global_position")
	var diff := (term_pos - host_pos).normalized()
	ai.set("wander_direction", diff)
	
	if host.has_method("_play_security_scan"):
		host.call("_play_security_scan")
		
	var upload_timer := host.get_meta(META_UPLOAD_TIMER) as float
	upload_timer -= delta
	if upload_timer <= 0.0:
		host.set_meta(META_UPLOAD_COOLDOWN, UPLOAD_INTERVAL_SEC)
		_reset_cyber_state(host)
	else:
		host.set_meta(META_UPLOAD_TIMER, upload_timer)


func _scan_for_nearby_terminal(host_pos: Vector3, ws: WorldState) -> Vector3i:
	var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
	for x in range(-3, 4):
		for y in range(-2, 3):
			for z in range(-3, 4):
				var check_coord := my_coord + Vector3i(x, y, z)
				if ws.get_block(check_coord) == 13: # 13 = Neon Magenta Terminal
					return check_coord
	return Vector3i(0, -999, 0)


# ==============================================================================
# SECURITY SWEEP & PATROLLING
# ==============================================================================

func _process_security_sweep(host: Object, ai: Object, delta: float) -> bool:
	var scan_timer := host.get_meta(META_SCAN_TIMER) as float
	scan_timer -= delta
	host.set_meta(META_SCAN_TIMER, scan_timer)
	
	if scan_timer <= 0.0:
		_trigger_robotic_sweep(host, ai)
		return true
	return false


func _trigger_robotic_sweep(host: Object, ai: Object) -> void:
	host.set_meta(META_STATE, State.SCANNING)
	ai.set("current_task", TASK_WORKING)
	_halt_movement(host, ai)
	
	var rot_step := host.get_meta(META_ROT_STEP) as int
	rot_step = (rot_step + 1) % 4
	host.set_meta(META_ROT_STEP, rot_step)
	
	var angle := float(rot_step) * (PI / 2.0)
	ai.set("wander_direction", Vector3(cos(angle), 0.0, sin(angle)))
	
	if host.has_method("_play_security_scan"):
		host.call("_play_security_scan")
		
	host.set_meta(META_SCAN_TIMER, SCAN_DURATION_SEC)


func _process_highway_patrol(host: Object, ai: Object, parent: Node, delta: float) -> void:
	host.set_meta(META_STATE, State.PATROLLING)
	ai.set("current_task", TASK_WANDERING)
	
	var wander_timer := host.get_meta(META_WANDER_TIMER) as float
	var wander_dir := host.get_meta(META_WANDER_DIR) as Vector3
	var host_pos: Vector3 = host.get("global_position")
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 5.0)
		var road_vector := _scan_for_paved_roads(host_pos, parent)
		wander_dir = road_vector if road_vector != Vector3.ZERO else Vector3(cos(randf() * TAU), 0.0, sin(randf() * TAU))
		host.set_meta(META_WANDER_DIR, wander_dir)
		
	host.set_meta(META_WANDER_TIMER, wander_timer)
	_apply_movement_vectors(host, ai, wander_dir, SPEED_PATROL)


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
				
				# STRICT TYPING FIX: Cast Variant explicitly to Vector3 before subtraction
				var diff := road_pos - host_pos
				diff.y = 0.0
				if diff.length() > 0.8:
					return diff.normalized()
	return Vector3.ZERO


func _halt_movement(host: Object, ai: Object) -> void:
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0; velocity.z = 0.0
	host.set("velocity", velocity)
	ai.set("wander_direction", Vector3.ZERO)


func _apply_movement_vectors(host: Object, ai: Object, wander_dir: Vector3, speed: float) -> void:
	var velocity: Vector3 = host.get("velocity") as Vector3
	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * speed
		velocity.z = wander_dir.z * speed
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_SCAN_TIMER): host.set_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC)
	if not host.has_meta(META_ROT_STEP): host.set_meta(META_ROT_STEP, 0)
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_UPLOAD_COOLDOWN): host.set_meta(META_UPLOAD_COOLDOWN, 5.0) 
	if not host.has_meta(META_UPLOAD_TIMER): host.set_meta(META_UPLOAD_TIMER, UPLOAD_DURATION_SEC)
	if not host.has_meta(META_STATE): host.set_meta(META_STATE, State.PATROLLING)


func _reset_cyber_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC)
	host.set_meta(META_ROT_STEP, 0)
	host.set_meta(META_WANDER_TIMER, 1.0)
	host.set_meta(META_UPLOAD_TIMER, UPLOAD_DURATION_SEC)
	host.set_meta(META_STATE, State.PATROLLING)


# ==============================================================================
# POLYMORPHIC TELEMETRY EXPOSURE (LSP / OCP Compliant)
# ==============================================================================

func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_STATE):
		return "WANDER"
		
	var state_val: int = host.get_meta(META_STATE) as int
	match state_val:
		State.PATROLLING: return "WANDER"      
		State.SCANNING: return "WORKING"       
		State.UPLOADING: return "WORKING"      
		State.FLEEING: return "PANIC"
		_: return "WANDER"
