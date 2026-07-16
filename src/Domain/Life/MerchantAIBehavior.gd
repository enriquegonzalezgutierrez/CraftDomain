# ==============================================================================
# Pathfile: res://src/Domain/Life/MerchantAIBehavior.gd
# Description: Specialized AI behavior strategy implementing mercantile routines for
#              the Village Merchant. 
#              UPGRADE: Implemented Localized State Machine, Tactical Panic Routing
#              to protectors, and a market-stalling Advertising Shout.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates exclusively mercantile schedules,
#   handshakes, and protective retreats. All methods kept strictly < 20 lines.
# - Open-Closed Principle (OCP): Extends IAIBehavior. Adds custom merchant behaviors
#   without modifying existing world or player entities.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MerchantAIBehavior
extends IAIBehavior

# Localized State Machine (SRP / OCP Compliant)
enum State {
	IDLE,         # Resting / Counting gold coins at night
	WANDERING,    # Navigating between refuge and stall
	TRADING,      # Standing actively behind the counter
	ADVERTISING,  # Voicing wares to attract village buyers
	FLEEING       # Running towards nearest Guard/Golem for safety
}

const SPEED_PATROL: float = 1.0
const SPEED_RETREAT: float = 1.6
const SPEED_PANIC: float = 2.4

const RANGE_SENSE_SQ: float = 64.0        # 8.0m threat detection
const RANGE_GUARD_SEEK_SQ: float = 900.0   # 30.0m protector seek radius

const COOLDOWN_COINS_SEC: float = 2.5
const COOLDOWN_SHOUT_MIN: float = 10.0
const COOLDOWN_SHOUT_MAX: float = 20.0

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_STATE := "merchant_local_state"
const META_WANDER_TIMER := "merchant_wander_timer"
const META_WANDER_DIR := "merchant_wander_dir"
const META_COOLDOWN := "merchant_gold_cooldown"
const META_SHOUT_COOLDOWN := "merchant_shout_cooldown"


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
	_update_timers(host, delta)
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	# Priority 1: Survival (Fleeing to nearest defender)
	if _process_threat_panic(host, ai, delta):
		return
		
	# Priority 2: Nighttime schedule (Refuge & gold counting)
	var parent: Node = host.call("get_parent") as Node
	if _process_nighttime_schedule(host, ai, parent, delta):
		return
		
	# Priority 3: Daytime business (Trading & Advertising)
	_process_daytime_business(host, ai, delta)


func _update_timers(host: Object, delta: float) -> void:
	var gold_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if gold_cooldown > 0.0:
		host.set_meta(META_COOLDOWN, gold_cooldown - delta)
		
	var shout_cooldown: float = host.get_meta(META_SHOUT_COOLDOWN) as float
	if shout_cooldown > 0.0:
		host.set_meta(META_SHOUT_COOLDOWN, shout_cooldown - delta)


# ==============================================================================
# TACTICAL PANIC & PROTECTION SEEKING
# ==============================================================================

func _process_threat_panic(host: Object, ai: Object, delta: float) -> bool:
	var is_panicking := ai.get("current_task") as int == TASK_PANIC
	if not is_panicking and _detect_threat_proximity(host):
		is_panicking = true
		ai.set("current_task", TASK_PANIC)
		
	if not is_panicking:
		return false
		
	host.set_meta(META_STATE, State.FLEEING)
	_execute_tactical_panic(host, ai, delta)
	return true


func _execute_tactical_panic(host: Object, ai: Object, delta: float) -> void:
	var wander_timer := host.get_meta(META_WANDER_TIMER) as float
	var wander_dir := host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(0.4, 1.0)
		var guard := _scan_for_closest_protector(host)
		if is_instance_valid(guard):
			wander_dir = (guard.global_position - host.get("global_position")).normalized()
			wander_dir.y = 0.0
		else:
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
			
	host.set_meta(META_WANDER_TIMER, wander_timer)
	host.set_meta(META_WANDER_DIR, wander_dir)
	_apply_movement_vectors(host, ai, wander_dir, SPEED_PANIC)


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
				if dist_sq <= RANGE_SENSE_SQ:
					return true
	return false


func _scan_for_closest_protector(host: Object) -> Node3D:
	if not host.call("is_inside_tree"): return null
	var passives: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			passives = tree.call("get_nodes_in_group", "passives")
			
	var host_pos: Vector3 = host.get("global_position")
	var closest_protector: Node3D = null
	var min_dist_sq := RANGE_GUARD_SEEK_SQ
	
	for child: Object in passives:
		if is_instance_valid(child) and child != host and child is Node3D:
			var name_str: String = child.get("name")
			if name_str.contains("GUARD") or name_str.contains("GOLEM"):
				var domain: Object = child.get("domain_entity")
				if domain != null and not domain.get("is_dead"):
					var dist_sq := host_pos.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest_protector = child as Node3D
	return closest_protector


# ==============================================================================
# NIGHTTIME COIN COUNTING
# ==============================================================================

func _process_nighttime_schedule(host: Object, ai: Object, parent: Node, _delta: float) -> bool:
	var is_night := CelestialService.is_night_time_static()
	if not is_night:
		return false
		
	var host_pos: Vector3 = host.get("global_position")
	var nav_service: Object = parent.get("navigation_service") if is_instance_valid(parent) else null
	
	if _is_inside_shelter(host_pos, nav_service):
		_execute_accounting_shimmers(host, ai)
	else:
		_route_nighttime_retreat(host, ai, nav_service, host_pos)
	return true


func _is_inside_shelter(host_pos: Vector3, nav_service: Object) -> bool:
	if is_instance_valid(nav_service) and "_indoor_nodes" in nav_service:
		var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
		var indoor_nodes: Array = nav_service.get("_indoor_nodes") as Array
		return indoor_nodes.has(my_coord)
	return false


func _execute_accounting_shimmers(host: Object, ai: Object) -> void:
	host.set_meta(META_STATE, State.IDLE)
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


func _route_nighttime_retreat(host: Object, ai: Object, nav_service: Object, host_pos: Vector3) -> void:
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
				
				ai.set("wander_direction", retreat_dir)
				ai.set("current_task", TASK_WANDERING)
				host.set_meta(META_STATE, State.WANDERING)


# ==============================================================================
# DAYTIME BUSINESS & ADVERTISING
# ==============================================================================

func _process_daytime_business(host: Object, ai: Object, delta: float) -> void:
	var wander_timer := host.get_meta(META_WANDER_TIMER) as float
	var wander_dir := host.get_meta(META_WANDER_DIR) as Vector3
	var host_pos: Vector3 = host.get("global_position")
	var spawn_point: Vector3 = host.get("_spawn_point") as Vector3
	
	# Verify if standing safely behind the market stall counter (Y=11 boundary)
	var is_at_stall := host_pos.distance_squared_to(spawn_point) <= 4.0
	
	if is_at_stall:
		_execute_stall_business(host, ai, delta)
	else:
		_route_to_stall(host, ai, spawn_point, host_pos, wander_timer, wander_dir, delta)


func _execute_stall_business(host: Object, ai: Object, _delta: float) -> void:
	_halt_movement(host, ai)
	
	var shout_cd := host.get_meta(META_SHOUT_COOLDOWN) as float
	if shout_cd <= 0.0:
		_trigger_advertising_shout(host, ai)
	else:
		host.set_meta(META_STATE, State.TRADING)
		ai.set("current_task", TASK_WORKING)


func _trigger_advertising_shout(host: Object, ai: Object) -> void:
	host.set_meta(META_STATE, State.ADVERTISING)
	ai.set("current_task", TASK_WORKING)
	host.set_meta(META_SHOUT_COOLDOWN, randf_range(COOLDOWN_SHOUT_MIN, COOLDOWN_SHOUT_MAX))
	
	# Spin 360 to shout wares in all directions
	var angle := float(Time.get_ticks_msec() / 150.0)
	ai.set("wander_direction", Vector3(cos(angle), 0.0, sin(angle)))
	
	if host.has_method("_play_advertising_shout"):
		host.call("_play_advertising_shout")


func _route_to_stall(host: Object, ai: Object, spawn_point: Vector3, host_pos: Vector3, timer: float, dir: Vector3, delta: float) -> void:
	host.set_meta(META_STATE, State.WANDERING)
	ai.set("current_task", TASK_WANDERING)
	
	var t := timer - delta
	var d := dir
	if t <= 0.0:
		t = randf_range(2.0, 5.0)
		d = (spawn_point - host_pos).normalized()
		d.y = 0.0
		host.set_meta(META_WANDER_DIR, d)
		
	host.set_meta(META_WANDER_TIMER, t)
	_apply_movement_vectors(host, ai, d, SPEED_PATROL)


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
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_SHOUT_COOLDOWN): host.set_meta(META_SHOUT_COOLDOWN, 5.0) # Grace period
	if not host.has_meta(META_STATE): host.set_meta(META_STATE, State.IDLE)


func _reset_merchant_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_WANDER_TIMER, 1.0)
	host.set_meta(META_STATE, State.IDLE)


# ==============================================================================
# POLYMORPHIC TELEMETRY EXPOSURE (LSP / OCP Compliant)
# ==============================================================================

func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_STATE):
		return "IDLE"
		
	var state_val: int = host.get_meta(META_STATE) as int
	match state_val:
		State.IDLE: return "IDLE"
		State.WANDERING: return "WANDERING"
		State.TRADING: return "CHAT"          # Mapeado a la UI "CHARLANDO EN CORRILLO"
		State.ADVERTISING: return "WORKING"   # Mapeado a la UI "RITUAL DE TRABAJO ACTIVO"
		State.FLEEING: return "PANIC"
		_: return "IDLE"
