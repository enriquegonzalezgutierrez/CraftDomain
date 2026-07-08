# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (AI Logic)
# Class: NPCAIComponent
# Description: Refactored AI component managing task timers, obstacle avoidance, 
#              and dynamic behavior delegation with a dual patrol-strategy engine.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Acts strictly as the task timer and 
#   coordination hub, delegating domain-specific decision trees to the injected 
#   IAIBehavior strategy.
# - Open-Closed Principle (OCP): Open for extension by accepting any subclass of 
#   IAIBehavior dynamically, while remaining closed to direct modifications.
# - Liskov Substitution Principle (LSP): Dynamically falls back to standard village 
#   social and wandering routines if the active strategy is currently in repose.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name NPCAIComponent
extends Node

## AI Behavioral States
enum TaskState {
	IDLE,       
	WANDERING,  
	EXAMINING,  
	GREETING,   
	CHATTIING,  
	PANIC,      
	WORKING     
}

# AI Constants
const SIGHT_RANGE: float = 8.0
const SIGHT_RANGE_SQ: float = 64.0  
const SOCIAL_RANGE: float = 3.0
const SOCIAL_RANGE_SQ: float = 9.0  
const GREET_DISTANCE: float = 3.5
const GREET_DISTANCE_SQ: float = 12.25 

# Active State properties
var current_task: TaskState = TaskState.IDLE
var task_timer: float = 2.0
var wander_direction: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0

# Social Cooldown Timer to resolve social freezes and infinite greeting loops
var social_cooldown: float = 0.0
const SOCIAL_COOLDOWN_INTERVAL: float = 8.0

# Injected Behavioral Strategy (OCP/SOLID compliant)
var active_behavior: IAIBehavior = null

# Asynchronous Scan Throttling Timer
var _tactical_scan_timer: float = 0.0
const SCAN_INTERVAL: float = 0.25 

# Reference to the controlled physical entity parent and spawn anchors
var _host: CharacterBody3D
var _spawn_point: Vector3

# Dynamic 3D Path-following parameters
var _nav_service: VoxelNavigationService = null
var _active_path: Array[Vector3] = []
var _current_path_index: int = 0

# Dynamic AI Tick rate tracker (LOD AI)
var _ai_tick_timer: float = 0.0


func _ready() -> void:
	name = "NPCAIComponent"
	_host = get_parent() as CharacterBody3D
	if is_instance_valid(_host):
		_spawn_point = _host.global_position
		_stagger_and_setup()
		print("[AI DEBUG] NPCAIComponent successfully attached to host: ", _host.name, " [Seed: ", _host.get("npc_seed"), "]")


## Staggers updates and queries WorldController for the shared navigation map
func _stagger_and_setup() -> void:
	_tactical_scan_timer = randf_range(0.0, SCAN_INTERVAL)
	
	get_tree().process_frame.connect(func() -> void:
		if is_instance_valid(_host) and _host.is_inside_tree():
			var world_ctrl := _host.get_parent()
			if is_instance_valid(world_ctrl) and "chunk_manager" in world_ctrl:
				if "navigation_service" in world_ctrl:
					_nav_service = world_ctrl.get("navigation_service") as VoxelNavigationService
					print("[AI DEBUG] ", _host.name, " successfully linked to global navigation service.")
	, CONNECT_ONE_SHOT)


## Core AI state-machine tick.
func process_ai(delta: float) -> void:
	if not is_instance_valid(_host):
		return
		
	# Skip standard state-machine calculations if the NPC is locked in dialog
	if _host.get("is_talking") == true:
		if current_task != TaskState.IDLE:
			print("[AI DEBUG] ", _host.name, " dialog lock activated, forcing IDLE state.")
		current_task = TaskState.IDLE
		wander_direction = Vector3.ZERO
		stuck_timer = 0.0
		_active_path.clear()
		_host.velocity.x = 0.0
		_host.velocity.z = 0.0
		return

	# Always tick timers continuously in real-time
	task_timer -= delta
	_tactical_scan_timer -= delta
	if social_cooldown > 0.0:
		social_cooldown -= delta

	# ==========================================================================
	# 1. EVALUATE TASK TRANSITIONS UNTHROTTLED (BUG FIX)
	# This guarantees task expiration is evaluated even if tick rates are throttled.
	# ==========================================================================
	if task_timer <= 0.0:
		_select_next_random_task()

	# ==========================================================================
	# 2. RUN POLYMORPHIC STRATEGY IF DELEGATED (OCP COMPLIANCE)
	# ==========================================================================
	if active_behavior != null:
		active_behavior.evaluate_and_execute(_host, self, delta)
		
		# DYNAMIC DELEGATION SHIELD
		var overrides: bool = active_behavior.get("overrides_wandering") == true
		if overrides or current_task == TaskState.WORKING:
			_process_movement_avoidance(delta)
			_apply_movement_vectors()
			return

	# ==========================================================================
	# 3. DYNAMIC AI TICK THROTTLING FOR FALLBACK BEHAVIOR (LOD AI)
	# ==========================================================================
	var player_node := _host.get_parent().get_node_or_null("Player") as CharacterBody3D
	var dist_sq := 999999.0
	if is_instance_valid(player_node):
		dist_sq = _host.global_position.distance_squared_to(player_node.global_position)
		
	var tick_interval := 0.05 
	if dist_sq > 1225.0:      
		tick_interval = 2.0
	elif dist_sq > 225.0:     
		tick_interval = 0.25
		
	_ai_tick_timer -= delta
	if _ai_tick_timer > 0.0:
		if current_task == TaskState.WANDERING or current_task == TaskState.PANIC:
			if not _is_direction_safe(wander_direction):
				print("[AI DEBUG] ", _host.name, " predicted path is unsafe during throttle, resetting path.")
				_active_path.clear()
				wander_direction = Vector3.ZERO
				task_timer = 0.0 
				
		_process_movement_avoidance(delta)
		_apply_movement_vectors()
		return
		
	_ai_tick_timer = tick_interval 

	# ==========================================================================
	# 4. TACTICAL PROXIMITY SCAN FOR FALLBACK BEHAVIOR
	# ==========================================================================
	if _tactical_scan_timer <= 0.0:
		_tactical_scan_timer = SCAN_INTERVAL
		
		# A. Threat Detection
		var closest_hostile := _detect_closest_zombie_threat()
		if closest_hostile != null:
			var escape_dir := (_host.global_position - closest_hostile.global_position).normalized()
			escape_dir.y = 0.0
			
			if _is_direction_safe(escape_dir):
				print("[AI DEBUG] ", _host.name, " detected threat: ", closest_hostile.name, "! Triggering escape PANIC.")
				current_task = TaskState.PANIC
				_active_path.clear() 
				wander_direction = escape_dir
				task_timer = 2.5 
				stuck_timer = 0.0
				_apply_movement_vectors()
				return
		
		# B. Check Environmental and Time Schedule
		var is_night: bool = CelestialService.is_night_time_static()
		var is_storming := false
		
		var world_node := _host.get_parent()
		if is_instance_valid(world_node):
			var weather_node := world_node.get_node_or_null("WeatherService")
			if is_instance_valid(weather_node):
				var current_weather: int = int(weather_node.get("current_weather"))
				is_storming = (current_weather == 1 or current_weather == 2)
				
		var is_civilian := false
		if _host.has_method("_get_humanoid_role"):
			var role: int = _host.call("_get_humanoid_role")
			is_civilian = (role >= 0 and role != 2 and role != 6)
		
		if (is_night or is_storming) and is_civilian:
			_seek_shelter_routine()
			_apply_movement_vectors()
			return
		
		# C. Check Player and Peer Social Interaction with cooldown limits (Hysteresis)
		var can_socialize: bool = _host.has_method("_can_socialize") and _host.call("_can_socialize") as bool
		
		# Dynamic compositions locator: safely fetch player via parent coordinator
		var actual_player: CharacterBody3D = null
		if is_instance_valid(world_node) and "player" in world_node:
			actual_player = world_node.get("player") as CharacterBody3D
			
		if can_socialize and social_cooldown <= 0.0 and current_task != TaskState.PANIC and current_task != TaskState.GREETING and current_task != TaskState.CHATTIING:
			if is_instance_valid(actual_player):
				var dist_p_sq := _host.global_position.distance_squared_to(actual_player.global_position)
				if dist_p_sq <= GREET_DISTANCE_SQ: 
					print("[AI DEBUG] ", _host.name, " proximity greeting triggered with Player.")
					current_task = TaskState.GREETING
					_active_path.clear()
					var look_dir := (actual_player.global_position - _host.global_position).normalized()
					look_dir.y = 0
					if look_dir != Vector3.ZERO:
						wander_direction = look_dir
					task_timer = randf_range(2.0, 4.0)
					social_cooldown = SOCIAL_COOLDOWN_INTERVAL
					
			var closest_peer := _detect_closest_peer_npc()
			if closest_peer != null:
				if randf() < 0.15:
					print("[AI DEBUG] ", _host.name, " proximity chatter triggered with peer: ", closest_peer.name)
					current_task = TaskState.CHATTIING
					_active_path.clear()
					var look_dir := (closest_peer.global_position - _host.global_position).normalized()
					look_dir.y = 0
					if look_dir != Vector3.ZERO:
						wander_direction = look_dir
					task_timer = randf_range(2.0, 4.0)
					social_cooldown = SOCIAL_COOLDOWN_INTERVAL

	if current_task == TaskState.WANDERING or current_task == TaskState.PANIC:
		if not _is_direction_safe(wander_direction):
			print("[AI DEBUG] ", _host.name, " dynamic path obstructed, changing direction.")
			_active_path.clear()
			_select_next_random_task()
		
	_process_movement_avoidance(delta)
	_apply_movement_vectors()


## Searches the navigation graph and compiles an A* path towards the closest cached indoor shelter
func _seek_shelter_routine() -> void:
	if current_task == TaskState.IDLE and _active_path.is_empty():
		var my_coord := Vector3i(floori(_host.global_position.x), floori(_host.global_position.y), floori(_host.global_position.z))
		if is_instance_valid(_nav_service) and _nav_service._indoor_nodes.has(my_coord):
			return 
			
	if not _active_path.is_empty() and current_task == TaskState.WANDERING:
		return 
		
	if is_instance_valid(_nav_service):
		var shelter_pos: Vector3 = _nav_service.find_closest_shelter_node(_host.global_position)
		if shelter_pos != Vector3.ZERO:
			var path := _nav_service.find_path(_host.global_position, shelter_pos)
			if path.size() > 1:
				print("[AI DEBUG] ", _host.name, " evening/storm routine: Routing AStar path to shelter at: ", shelter_pos)
				_active_path = path
				_current_path_index = 0
				current_task = TaskState.WANDERING
				task_timer = 15.0 
				return
				
	current_task = TaskState.IDLE
	_active_path.clear()
	task_timer = randf_range(1.5, 3.0)


## Calculates and applies velocities to the parent host based on task states
func _apply_movement_vectors() -> void:
	var base_speed: float = 1.3
	
	if "SPEED" in _host:
		var raw_s: Variant = _host.get("SPEED")
		if raw_s != null: base_speed = float(raw_s)
	elif "BASE_SPEED" in _host:
		var raw_bs: Variant = _host.get("BASE_SPEED")
		if raw_bs != null: base_speed = float(raw_bs)
	
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
					print("[AI DEBUG] ", _host.name, " successfully reached targeted AStar path node destination.")
					_active_path.clear()
					current_task = TaskState.IDLE
					task_timer = randf_range(0.4, 1.2) # Short rest interval for high dynamism
					_host.velocity.x = 0.0
					_host.velocity.z = 0.0
					stuck_timer = 0.0
					return
			
			var speed_mult := 2.8 if current_task == TaskState.PANIC else 1.0
			_host.velocity.x = wander_direction.x * base_speed * speed_mult
			_host.velocity.z = wander_direction.z * base_speed * speed_mult
			
			var is_tethered_npc: bool = _host.has_method("_has_ui_decorations") and _host.call("_has_ui_decorations") as bool
			if is_tethered_npc:
				if _host.global_position.distance_squared_to(_spawn_point) > 144.0: 
					print("[AI DEBUG] ", _host.name, " exceeded maximum spawn tether distance, routing back home.")
					_active_path.clear()
					wander_direction = (_spawn_point - _host.global_position).normalized()
					wander_direction.y = 0


## Jumps over wall collisions or recalculates path trajectories (OCP Jump Shield)
func _process_movement_avoidance(delta: float) -> void:
	if current_task != TaskState.WANDERING and current_task != TaskState.PANIC:
		return
		
	if _host.is_on_wall():
		if _host.is_on_floor():
			var jump_vel: float = 5.0
			if "JUMP_VELOCITY" in _host:
				var jv: Variant = _host.get("JUMP_VELOCITY")
				if jv != null: jump_vel = float(jv)
				
			# ==================================================================
			# COORDINATE-BASED JUMP EVALUATION (BUG FIX / LSP)
			# Calculate exact destination voxel above the wall we are hitting 
			# to prevent aquatic breaching while enabling underwater step climbs.
			# ==================================================================
			var wall_normal := _host.get_wall_normal()
			var step_dir := -wall_normal # Vector direction towards the block face
			var projected_pos := _host.global_position + step_dir * 0.8
			var target_coord := Vector3i(floori(projected_pos.x), floori(projected_pos.y) + 1, floori(projected_pos.z))
			
			var is_jump_capable: bool = true
			if _host.has_method("_can_jump_to"):
				is_jump_capable = _host.call("_can_jump_to", target_coord) as bool
				
			if is_jump_capable:
				_host.velocity.y = jump_vel
				print("[AI DEBUG] [", _host.name, "] climbing wall obstacle cleanly towards coordinate: ", target_coord)
			else:
				print("[AI DEBUG] [", _host.name, "] climb BLOCKED: Target coordinate ", target_coord, " violates habitat rules.")
			
		stuck_timer += delta
		if stuck_timer > 0.12: 
			stuck_timer = 0.0
			var wall_normal := _host.get_wall_normal()
			var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
			if flat_normal != Vector3.ZERO:
				print("[AI DEBUG] ", _host.name, " wall collision detected, executing bounce course-correction.")
				wander_direction = wander_direction.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.3, 0.3)).normalized()
				_active_path.clear()
	else:
		stuck_timer = 0.0


## Smart-Checking Wandering (BUG FIX: Re-balanced active weights for maximum dynamism)
func _select_next_random_task() -> void:
	var roll := randf()
	var old_task := current_task
	
	if roll < 0.70: # 70% chance to WALK actively
		current_task = TaskState.WANDERING
		_active_path.clear()
		
		if is_instance_valid(_nav_service):
			var wander_range := 8.0
			var target_offset := Vector3(randf_range(-wander_range, wander_range), 0.0, randf_range(-wander_range, wander_range))
			var target_pos := _host.global_position + target_offset
			
			var path := _nav_service.find_path(_host.global_position, target_pos)
			if path.size() > 1:
				_active_path = path
				_current_path_index = 0
				task_timer = randf_range(5.0, 10.0)
				print("[AI DEBUG] ", _host.name, " State Shift: ", old_task, " -> WANDERING (AStar Route locked to: ", target_pos, ")")
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
			task_timer = randf_range(0.4, 1.2) # Short rest interval
			print("[AI DEBUG] ", _host.name, " State Shift: ", old_task, " -> IDLE (No safe directions found during wander scan)")
			return
			
		task_timer = randf_range(3.0, 7.0)
		print("[AI DEBUG] ", _host.name, " State Shift: ", old_task, " -> WANDERING (Fallback flat direction: ", wander_direction, ")")
	elif roll < 0.85: # 15% chance to pause and EXAMINE surroundings
		current_task = TaskState.EXAMINING 
		_active_path.clear()
		var angle := randf() * TAU
		wander_direction = Vector3(cos(angle), 0, sin(angle))
		task_timer = randf_range(1.0, 2.5) # Fast analysis interval
		print("[AI DEBUG] ", _host.name, " State Shift: ", old_task, " -> EXAMINING (Analyzing heading: ", wander_direction, ")")
	else: # 15% chance of short peaceful rest in place (IDLE)
		current_task = TaskState.IDLE
		_active_path.clear()
		task_timer = randf_range(0.4, 1.2) # Short resting interval
		print("[AI DEBUG] ", _host.name, " State Shift: ", old_task, " -> IDLE (Resting and breathing in place)")


## Look-Ahead Validator: Protects land mobs from drowning and constrains aquatic species
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
		return block_below == BlockType.Type.WATER or block_at == BlockType.Type.WATER
	elif habitat == 1: # AMPHIBIOUS
		var is_water: bool = block_below == BlockType.Type.WATER or block_at == BlockType.Type.WATER
		var is_shore: bool = block_below == BlockType.Type.SAND or block_below == BlockType.Type.MUD
		return is_water or is_shore
	else: # TERRESTRIAL
		var is_water: bool = block_below == BlockType.Type.WATER or block_below == BlockType.Type.LAVA or block_at == BlockType.Type.WATER
		var is_void: bool = block_below == BlockType.Type.AIR
		
		if is_void:
			var block_2_below := ws.get_block(block_below_coord + Vector3i(0, -1, 0))
			if block_2_below != BlockType.Type.AIR and block_2_below != BlockType.Type.WATER and block_2_below != BlockType.Type.LAVA:
				is_void = false
				
		return not is_water and not is_void


## Scanning for hostiles utilizing Godot's O(1) group lookup
func _detect_closest_zombie_threat() -> Node3D:
	if not is_instance_valid(_host) or not _host.is_inside_tree():
		return null
		
	var closest_zombie: Node3D = null
	var min_dist_sq := SIGHT_RANGE_SQ
	
	var hostiles := _host.get_tree().get_nodes_in_group("hostiles")
	for child: Node in hostiles:
		if is_instance_valid(child):
			var zombie_entity: VoxelEntity = child.get("domain_entity") as VoxelEntity
			if zombie_entity != null and not zombie_entity.is_dead:
				var dist_sq := _host.global_position.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_zombie = child as Node3D
					
	return closest_zombie


## Scanning for peers utilizing Godot's O(1) group lookup
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
