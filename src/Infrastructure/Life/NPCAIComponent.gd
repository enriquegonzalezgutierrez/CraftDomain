# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (NPC Sensory AI Brain)
# Class: NPCAIComponent
# Description: Rigging component managing task timers, obstacle avoidance, 
#              and physical step-climbing assistance.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Actively manages the physical translation,
#   whisker raycast steering, and pathing state of the NPC, delegating complex 
#   behavior schedules to isolated domain strategies.
# - Open-Closed Principle (OCP): Completely decoupled from concrete humanoid roles. 
#   Exclusions from weather/night shelter-seeking are queried polimorphically 
#   from the host's `can_take_shelter()` contract, closing this file to changes.
# - Liskov Substitution Principle (LSP): Functions uniformly across all passive and
#   hostile entity classes.
# ==============================================================================
class_name NPCAIComponent
extends Node

# Generic Task States maintained strictly as a data-contract for the animation blenders (LSP/OCP)
enum TaskState {
	IDLE,       
	WANDERING,  
	EXAMINING,  
	GREETING,   
	CHATTIING,  
	PANIC,      
	WORKING     
}

# ==============================================================================
# CLASS MEMBER VARIABLES
# ==============================================================================
## Injected AI Strategy contract (OCP Compliant)
@export var active_behavior: IAIBehavior

# Live physics and animation data-carriers (SRP compliant, read/written by strategies)
var current_task: TaskState = TaskState.IDLE
var wander_direction: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0
var task_timer: float = 0.0
var social_cooldown: float = 0.0

# Performance Lod tracker
var _ai_timer_accum: float = 0.0
var _ai_tick_rate: float = 0.25 # Standard throttled tick rate for decisions (4Hz)

# Fallback movement and sensory ranges (OCP/SOLID compliant)
var SIGHT_RANGE_SQ: float = 64.0
var SOCIAL_RANGE_SQ: float = 9.0
var GREET_DISTANCE_SQ: float = 12.25
const SOCIAL_COOLDOWN_INTERVAL: float = 8.0

# Pathfinding coordinates trackers
var _active_path: Array[Vector3] = []
var _current_path_index: int = 0

# Sibling Component references
var _host: CharacterBody3D
var _nav_service: Object # Decoupled navigation service lookup


func _ready() -> void:
	name = "NPCAIComponent"
	_host = get_parent() as CharacterBody3D
	_ai_timer_accum = randf_range(0.0, _ai_tick_rate)


## Core processing tick executing physics-sensitive avoidance and decision throttling
func process_ai(delta: float) -> void:
	if not is_instance_valid(_host) or _host.get("domain_entity") == null or _host.domain_entity.is_dead:
		return
		
	# --- TELEMETRY FLUSH DISPATCH (DIP Compliant) ---
	if is_instance_valid(AITelemetryService.instance):
		AITelemetryService.instance.process_telemetry_flush(delta)
		
	# ==========================================================================
	# HIGH-PERFORMANCE UN-THROTTLED PHYSICS ENGINE
	# Apply sensory obstacle avoidance and step-climbing assistance EVERY FRAME (120Hz)
	# ==========================================================================
	_process_movement_avoidance(delta)
	
	var has_override := false

	_ai_timer_accum += delta
	if _ai_timer_accum < _ai_tick_rate:
		has_override = false
		if active_behavior != null and active_behavior.get("overrides_wandering") == true:
			has_override = true
			
		if not has_override:
			_apply_movement_vectors()
		return
		
	# Reset decision clock once threshold is satisfied (runs at 4Hz)
	_ai_timer_accum = 0.0
	
	_locate_navigation_service_if_missing()
	
	# ==========================================================================
	# DELEGATED DOMAIN STRATEGY PIPELINE (DDD / SOLID COMPLIANCE)
	# Execute the active behavior strategy, letting it decide its own states,
	# velocities, and write into the animation data carriers.
	# ==========================================================================
	if active_behavior != null:
		active_behavior.evaluate_and_execute(_host, _ai_tick_rate)
		has_override = active_behavior.get("overrides_wandering") == true

	# ==========================================================================
	# UNFREEZE SCHEDULER: RUN FALLBACK VILLAGE PATROLS
	# Only run standard wandering routines for entities that do NOT override them 
	# ==========================================================================
	if not has_override:
		_process_fallback_village_routines()
		_apply_movement_vectors()
		
	# --- TELEMETRY LOG TRANSMISSION ---
	_dispatch_active_telemetry()


## Standard fallback behaviors executed when no specialized domain override is active
func _process_fallback_village_routines() -> void:
	# Evaluate state durations
	if task_timer <= 0.0:
		_select_next_random_task()
		
	# Scan for local threats
	var closest_hostile := _detect_closest_zombie_threat()
	if closest_hostile != null:
		var escape_dir := (_host.global_position - closest_hostile.global_position).normalized()
		escape_dir.y = 0.0
		
		if _is_direction_safe(escape_dir):
			current_task = TaskState.PANIC
			_active_path.clear() 
			wander_direction = escape_dir
			task_timer = 2.5 
			stuck_timer = 0.0
			_apply_movement_vectors()
			return
			
	# Check Environmental and Time Schedule
	var is_night: bool = CelestialService.is_night_time_static()
	var is_storming := false
	
	var world_node := _host.get_parent()
	if is_instance_valid(world_node):
		var weather_node := world_node.get_node_or_null("WeatherService")
		if is_instance_valid(weather_node):
			var cur_weather: Variant = weather_node.get("current_weather")
			if cur_weather != null:
				var w_val: int = int(cur_weather)
				is_storming = (w_val == 1 or w_val == 2)
			
	# OCP RESOLUTION: Determine if the entity needs shelter polimorphically.
	# Removes hardcoded role indexes and excludes guards/golems dynamically.
	var can_take_shelter := false
	if _host.has_method("can_take_shelter"):
		can_take_shelter = _host.call("can_take_shelter") as bool
	elif _host.has_method("_get_humanoid_role"):
		var role: int = _host.call("_get_humanoid_role")
		# Legacy fallback check: civilians (role >= 0, excluding guards (2) and golems (6))
		can_take_shelter = (role >= 0 and role != 2 and role != 6)
		
	if (is_night or is_storming) and can_take_shelter:
		_seek_shelter_routine()
		_apply_movement_vectors()
		return
		
	# Check Social Interactions
	var can_socialize: bool = _host.has_method("_can_socialize") and _host.call("_can_socialize") as bool
	var actual_player: CharacterBody3D = null
	if is_instance_valid(world_node) and "player" in world_node:
		actual_player = world_node.get("player") as CharacterBody3D
		
	if can_socialize and social_cooldown <= 0.0 and current_task != TaskState.PANIC and current_task != TaskState.GREETING and current_task != TaskState.CHATTIING:
		if is_instance_valid(actual_player):
			var dist_p_sq := _host.global_position.distance_squared_to(actual_player.global_position)
			if dist_p_sq <= GREET_DISTANCE_SQ: 
				current_task = TaskState.GREETING
				_active_path.clear()
				var look_dir := (actual_player.global_position - _host.global_position).normalized()
				look_dir.y = 0
				if look_dir != Vector3.ZERO:
					wander_direction = look_dir
				task_timer = randf_range(2.0, 4.0)
				social_cooldown = SOCIAL_COOLDOWN_INTERVAL
				_apply_movement_vectors()
				return
				
		var closest_peer := _detect_closest_peer_npc()
		if closest_peer != null:
			if randf() < 0.15:
				current_task = TaskState.CHATTIING
				_active_path.clear()
				var look_dir := (closest_peer.global_position - _host.global_position).normalized()
				look_dir.y = 0
				if look_dir != Vector3.ZERO:
					wander_direction = look_dir
				task_timer = randf_range(2.0, 4.0)
				social_cooldown = SOCIAL_COOLDOWN_INTERVAL
				_apply_movement_vectors()
				return
				
	if current_task == TaskState.WANDERING or current_task == TaskState.PANIC:
		if not _is_direction_safe(wander_direction):
			_active_path.clear()
			_select_next_random_task()


func _locate_navigation_service_if_missing() -> void:
	if _nav_service == null and is_instance_valid(_host):
		var parent := _host.get_parent()
		if is_instance_valid(parent) and "navigation_service" in parent:
			_nav_service = parent.get("navigation_service")


## Evaluates time and storm conditions to trigger shelter-seeking routes
func _seek_shelter_routine() -> void:
	if current_task == TaskState.IDLE and _active_path.is_empty():
		var my_coord := Vector3i(floori(_host.global_position.x), floori(_host.global_position.y), floori(_host.global_position.z))
		if is_instance_valid(_nav_service) and "_indoor_nodes" in _nav_service:
			var indoor_nodes: Array = _nav_service.get("_indoor_nodes")
			if indoor_nodes.has(my_coord):
				return 
				
	if not _active_path.is_empty() and current_task == TaskState.WANDERING:
		return 
		
	if is_instance_valid(_nav_service) and _nav_service.has_method("find_closest_shelter_node"):
		var shelter_pos: Vector3 = _nav_service.call("find_closest_shelter_node", _host.global_position)
		if shelter_pos != Vector3.ZERO:
			var path: Array = _nav_service.call("find_path", _host.global_position, shelter_pos)
			if path.size() > 1:
				_active_path.clear()
				for node: Vector3 in path:
					_active_path.append(node)
				_current_path_index = 0
				current_task = TaskState.WANDERING
				task_timer = 15.0 
				return
				
	current_task = TaskState.IDLE
	_active_path.clear()
	task_timer = randf_range(1.5, 3.0)


## Translates mathematical task targets into physical physics velocities
func _apply_movement_vectors() -> void:
	var base_speed: float = 1.3
	if "BASE_SPEED" in _host:
		base_speed = _host.get("BASE_SPEED")
		
	match current_task:
		TaskState.IDLE, TaskState.GREETING, TaskState.CHATTIING:
			_host.velocity.x = move_toward(_host.velocity.x, 0.0, base_speed)
			_host.velocity.z = move_toward(_host.velocity.z, 0.0, base_speed)
			stuck_timer = 0.0
			
		TaskState.EXAMINING:
			_host.velocity.x = wander_direction.x * (base_speed * 0.25)
			_host.velocity.z = wander_direction.z * (base_speed * 0.25)
			stuck_timer = 0.0
			
		TaskState.WANDERING, TaskState.PANIC:
			if current_task == TaskState.WANDERING and _active_path.size() > 0:
				if _current_path_index < _active_path.size():
					var target_node: Vector3 = _active_path[_current_path_index]
					var diff: Vector3 = target_node - _host.global_position
					diff.y = 0.0 
					
					if diff.length_squared() < 0.16:
						_current_path_index += 1
						_apply_movement_vectors()
						return
						
					wander_direction = diff.normalized()
				else:
					_active_path.clear()
					current_task = TaskState.IDLE
					task_timer = randf_range(0.4, 1.2)
					_host.velocity.x = 0.0
					_host.velocity.z = 0.0
					stuck_timer = 0.0
					return
					
			var speed_mult := 2.8 if current_task == TaskState.PANIC else 1.0
			_host.velocity.x = wander_direction.x * base_speed * speed_mult
			_host.velocity.z = wander_direction.z * base_speed * speed_mult
			
			var is_tethered_npc: bool = _host.has_method("_has_ui_decorations") and _host.call("_has_ui_decorations") as bool
			if is_tethered_npc:
				var spawn_pt: Vector3 = _host.get("_spawn_point") if "_spawn_point" in _host else _host.global_position
				
				if _host.global_position.distance_squared_to(spawn_pt) > 144.0: 
					_active_path.clear()
					wander_direction = (spawn_pt - _host.global_position).normalized()
					wander_direction.y = 0


# ==============================================================================
# PROACTIVE SENSORY OBSTACLE EVASION (Whisker Raycasts)
# ==============================================================================

## Steers movement away from imminent solid block collisions detected ahead
func _perform_proactive_whisker_avoidance(delta: float) -> void:
	if wander_direction == Vector3.ZERO:
		return
		
	var space_state := _host.get_world_3d().direct_space_state
	if space_state == null:
		return
		
	var host_pos := _host.global_position
	
	# Determine logical height of the collider to position rays at chest-level
	var r_origin := host_pos + Vector3(0.0, 0.9, 0.0)
	if "EntityCollider" in _host:
		var col: CollisionShape3D = _host.get_node_or_null("EntityCollider") as CollisionShape3D
		if is_instance_valid(col) and col.position.y > 0.1:
			r_origin = host_pos + Vector3(0.0, col.position.y, 0.0)
			
	var scan_distance := 1.2
	
	# Formulate our three look-ahead vectors: Center, Left (30 deg), Right (30 deg)
	var center_dir := wander_direction.normalized()
	var left_dir := center_dir.rotated(Vector3.UP, deg_to_rad(30.0))
	var right_dir := center_dir.rotated(Vector3.UP, deg_to_rad(-30.0))
	
	var scan_dirs := [center_dir, left_dir, right_dir]
	var best_avoidance_normal := Vector3.ZERO
	var closest_hit_dist := 999.0
	
	for dir: Vector3 in scan_dirs:
		var query := PhysicsRayQueryParameters3D.create(r_origin, r_origin + dir * scan_distance)
		query.collision_mask = 1 
		query.exclude = [_host.get_rid()]
		
		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			var hit_pos: Vector3 = result["position"]
			var hit_normal: Vector3 = result["normal"]
			var dist := r_origin.distance_to(hit_pos)
			
			if dist < closest_hit_dist:
				closest_hit_dist = dist
				best_avoidance_normal = hit_normal
	
	# If a close obstacle is detected, steer the velocity away proactively
	if best_avoidance_normal != Vector3.ZERO:
		var flat_normal := Vector3(best_avoidance_normal.x, 0.0, best_avoidance_normal.z).normalized()
		if flat_normal != Vector3.ZERO:
			var steer_target := wander_direction.bounce(flat_normal).normalized()
			wander_direction = wander_direction.lerp(steer_target, delta * 8.0).normalized()


# ==============================================================================
# CENTRALIZED STEP-CLIMB JUMP SOLVER & RECOVERY STUCK ENGINE
# ==============================================================================
func _process_movement_avoidance(_delta: float) -> void:
	_perform_proactive_whisker_avoidance(_delta)
		
	# Reactive Fallback: Jump or bounce if physically blocked by a wall
	if _host.is_on_wall():
		stuck_timer += _delta
		
		var world_node := _host.get_parent()
		
		if _host.is_on_floor():
			var flat_vel := Vector2(_host.velocity.x, _host.velocity.z)
			var speed := flat_vel.length()
			var is_physically_blocked := speed < 0.35
			
			var last_jump: float = _host.get_meta("last_jump_time") if _host.has_meta("last_jump_time") else 0.0
			var current_time := Time.get_ticks_msec() / 1000.0
			var can_jump := (current_time - last_jump) > 0.4
			
			# ----------------==================================================
			# ANTI-CEILING SMASHING SOLVER (SOLID Physics boundary scan)
			# --------------------------------==================================
			var head_coord := Vector3i(
				floori(_host.global_position.x),
				floori(_host.global_position.y) + 2, # Block directly above head (2.0m height)
				floori(_host.global_position.z)
			)
			var is_ceiling_solid := false
			if is_instance_valid(world_node) and "world_state" in world_node:
				var ws: WorldState = world_node.world_state
				if ws != null:
					is_ceiling_solid = BlockType.is_solid(ws.get_block(head_coord))
			
			# Block the jump completely if a wooden/stone ceiling is above their head!
			if is_physically_blocked and can_jump and not is_ceiling_solid:
				var jump_vel: float = 5.0
				if "JUMP_VELOCITY" in _host:
					jump_vel = _host.get("JUMP_VELOCITY")
					
				var wall_normal := _host.get_wall_normal()
				var step_dir := -wall_normal 
				var projected_pos := _host.global_position + step_dir * 0.8
				var target_coord := Vector3i(floori(projected_pos.x), floori(projected_pos.y) + 1, floori(projected_pos.z))
				
				var is_jump_capable := true
				if _host.has_method("_can_jump_to"):
					is_jump_capable = _host.call("_can_jump_to", target_coord) as bool
					
				# ----------------==================================================
				# SMART STEP-CLIMBING VERIFIER: Only jump if there is an actual climbable 1-block step
				# --------------------------------==================================
				var is_step_climbable := false
				if is_instance_valid(world_node) and "world_state" in world_node and world_node.world_state != null:
					var ws: WorldState = world_node.world_state
					var block_at_step_feet := ws.get_block(Vector3i(target_coord.x, target_coord.y - 1, target_coord.z))
					var block_at_step_chest := ws.get_block(target_coord)
					# Climbing is only valid if the obstacle is 1 block high (feet solid, chest empty)
					is_step_climbable = BlockType.is_solid(block_at_step_feet) and not BlockType.is_solid(block_at_step_chest)
					
				if is_jump_capable and is_step_climbable:
					_host.velocity.y = jump_vel
					_host.set_meta("last_jump_time", current_time)
					
		# ======================================================================
		# 3. RECOVERY STUCK ENGINE (LSP/OCP Compliant)
		# ======================================================================
		if stuck_timer > 0.35: 
			stuck_timer = 0.0
			var wall_normal := _host.get_wall_normal()
			var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
			if flat_normal != Vector3.ZERO:
				# Slide laterally: Rotate 90 degrees left or right randomly
				var slide_dir := Vector3(-flat_normal.z, 0.0, flat_normal.x) if randf() > 0.5 else Vector3(flat_normal.z, 0.0, -flat_normal.x)
				wander_direction = slide_dir.normalized()
				
				# Clear the stale path so the navigation service recalculates clean nodes
				if _host.has_meta("avian_flight_state") == false: # Do not clear paths for flying avians
					_active_path.clear()
					# Reset task state to IDLE so they halt and select an unobstructed direction instantly on next tick!
					current_task = TaskState.IDLE
					task_timer = 0.1
				
				# Exert a slight hop to escape voxel corner clippings ONLY if it's a climbable step
				if _host.is_on_floor() and not _host.call("_is_avian") as bool:
					var step_dir := wander_direction
					var projected_pos := _host.global_position + step_dir * 0.8
					var target_coord := Vector3i(floori(projected_pos.x), floori(projected_pos.y) + 1, floori(projected_pos.z))
					
					var is_step_climbable := false
					if is_instance_valid(world_node) and "world_state" in world_node and world_node.world_state != null:
						var ws: WorldState = world_node.world_state
						var block_at_step_feet := ws.get_block(Vector3i(target_coord.x, target_coord.y - 1, target_coord.z))
						var block_at_step_chest := ws.get_block(target_coord)
						is_step_climbable = BlockType.is_solid(block_at_step_feet) and not BlockType.is_solid(block_at_step_chest)
						
					if is_step_climbable:
						var hop_vel: float = 4.0
						if "JUMP_VELOCITY" in _host:
							hop_vel = _host.get("JUMP_VELOCITY") * 0.8
						_host.velocity.y = hop_vel
	else:
		stuck_timer = 0.0


## Calculates random next tasks or triggers pathfinding towards random points
func _select_next_random_task() -> void:
	var roll := randf()
	
	if roll < 0.70:
		current_task = TaskState.WANDERING
		_active_path.clear()
		
		if is_instance_valid(_nav_service) and _nav_service.has_method("find_path"):
			var wander_range := 8.0
			var target_offset := Vector3(randf_range(-wander_range, wander_range), 0.0, randf_range(-wander_range, wander_range))
			var target_pos := _host.global_position + target_offset
			
			var path: Array = _nav_service.call("find_path", _host.global_position, target_pos)
			if path.size() > 1:
				_active_path.clear()
				for node: Vector3 in path:
					_active_path.append(node)
				_current_path_index = 0
				task_timer = randf_range(5.0, 10.0)
				return
				
		var angle := randf() * TAU
		var dir := Vector3(cos(angle), 0, sin(angle))
		
		var found_safe := false
		for attempt in range(5):
			if _is_direction_safe(dir):
				wander_direction = dir
				found_safe = true
				break
			angle = randf() * TAU
			dir = Vector3(cos(angle), 0, sin(angle))
			
		if not found_safe:
			current_task = TaskState.IDLE
			wander_direction = Vector3.ZERO
			task_timer = randf_range(0.4, 1.2)
			return
			
		task_timer = randf_range(3.0, 7.0)
	elif roll < 0.85:
		current_task = TaskState.EXAMINING 
		_active_path.clear()
		var angle := randf() * TAU
		wander_direction = Vector3(cos(angle), 0, sin(angle))
		task_timer = randf_range(1.0, 2.5)
	else:
		current_task = TaskState.IDLE
		_active_path.clear()
		task_timer = randf_range(0.4, 1.2)


## Checks if a certain direction is safe from deep liquids, voids, or solid walls
func _is_direction_safe(dir: Vector3) -> bool:
	if not is_instance_valid(_host):
		return false
		
	var world_node := _host.get_parent()
	if not is_instance_valid(world_node) or not "world_state" in world_node:
		return true
		
	var ws: WorldState = world_node.world_state
	if ws == null:
		return true
		
	var check_pos := _host.global_position + dir * 1.5
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	var block_below := ws.get_block(block_below_coord)
	var block_at := ws.get_block(block_at_coord)
	
	var habitat: int = 0
	if _host.has_method("_get_habitat"):
		habitat = _host.call("_get_habitat") as int
			
	if habitat == 2: # AQUATIC
		return block_below == 6 or block_at == 6 # 6 = WATER
	elif habitat == 1: # AMPHIBIOUS
		var is_water: bool = block_below == 6 or block_at == 6
		var is_shore: bool = block_below == 7 or block_below == 11 # 7 = SAND, 11 = MUD
		# Symmetrical wall check: prevent amphibious scuttling straight into solid stone borders
		if BlockType.is_solid(block_at):
			return false
		return is_water or is_shore
	else: # TERRESTRIAL
		# Proactively reject walking paths pointing straight into solid blocking walls
		if BlockType.is_solid(block_at):
			return false
			
		var is_liquid: bool = block_below == 6 or block_below == 15 or block_at == 6 # 15 = LAVA
		var is_void: bool = block_below == 0 # 0 = AIR
		
		if is_void:
			var block_2_below := ws.get_block(block_below_coord + Vector3i(0, -1, 0))
			if block_2_below != 0 and block_2_below != 6 and block_2_below != 15:
				is_void = false
				
		return not is_liquid and not is_void


func _detect_closest_zombie_threat() -> Node3D:
	if not is_instance_valid(_host) or not _host.is_inside_tree():
		return null
		
	var closest_zombie: Node3D = null
	var min_dist_sq := SIGHT_RANGE_SQ
	
	var hostiles := _host.get_tree().get_nodes_in_group("hostiles")
	for child: Node in hostiles:
		if child == _host:
			continue
			
		if is_instance_valid(child):
			var zombie_entity: VoxelEntity = child.get("domain_entity") as VoxelEntity
			if zombie_entity != null and not zombie_entity.is_dead:
				var dist_sq := _host.global_position.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_zombie = child as Node3D
					
	return closest_zombie


func _detect_closest_peer_npc() -> Node3D:
	if not is_instance_valid(_host) or not _host.is_inside_tree():
		return null
		
	var closest_peer: Node3D = null
	var min_dist_sq := SOCIAL_RANGE_SQ
	
	var passives := _host.get_tree().get_nodes_in_group("passives")
	for child: Node in passives:
		if child != _host and is_instance_valid(child):
			var ai_comp: NPCAIComponent = child.get_node_or_null("NPCAIComponent") as NPCAIComponent
			if is_instance_valid(ai_comp):
				var peer_state: TaskState = ai_comp.current_task
				if peer_state == TaskState.IDLE or peer_state == TaskState.CHATTIING:
					var dist_sq := _host.global_position.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest_peer = child as Node3D
						
	return closest_peer


# ==============================================================================
# TELEMETRY LOG DISPATCHING SERVICES
# ==============================================================================

## Formulates and dispatches current diagnostic parameters to the Telemetry Service
func _dispatch_active_telemetry() -> void:
	if is_instance_valid(AITelemetryService.instance) and is_instance_valid(_host):
		var active_task_name := "IDLE"
		if active_behavior != null and active_behavior.has_method("get_active_state_name"):
			active_task_name = str(active_behavior.call("get_active_state_name", _host))
		else:
			active_task_name = _get_task_state_name(current_task)
			
		var waypoints_left := _active_path.size() - _current_path_index if _active_path.size() > 0 else 0
		
		# Normalize key names to match localization files
		var lookup_key := active_task_name
		if lookup_key == "WANDERING":
			lookup_key = "WANDER"
		elif lookup_key == "CHATTING":
			lookup_key = "CHAT"
		
		var localized_task_name := tr("SHOWCASE_TASK_" + lookup_key).to_upper()
		
		AITelemetryService.log_movement(
			_host.name,
			_host.global_position,
			_host.velocity,
			wander_direction,
			localized_task_name,
			_host.is_on_wall(),
			_host.is_on_floor(),
			waypoints_left
		)


## Mps task indexes safely to string tokens (OCP Compliant)
func _get_task_state_name(task_val: int) -> String:
	var names := ["IDLE", "WANDERING", "EXAMINING", "GREETING", "CHATTING", "PANIC", "WORKING"]
	if task_val >= 0 and task_val < names.size():
		return names[task_val]
	return "IDLE"
