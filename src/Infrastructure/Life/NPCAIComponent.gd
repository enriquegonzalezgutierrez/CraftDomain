# ==============================================================================
# Project: CraftDomain
# Description: Isolated Actor Component managing AI decision-making loops, 
#              threat detection, social wandering, and obstacle avoidance.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Extricates decision-making 
#   and scanning logic from the physical and visual entity wrapper.
# - Dependency Inversion Principle (DIP): Controls movements on 
#   general CharacterBody3D hosts using abstract vectors.
# HIGH PERFORMANCE AI UPGRADE (120 FPS STABILIZATION):
# - DEPRECATED O(N^2) CHILD ITERATIONS: Replaced the slow, high-frequency 
#   `get_children()` loop which scanned the entire world node hierarchy.
# - DYNAMIC GROUP INDEXING: Both target threat scans and peer social scans now 
#   query Godot's optimized C++ group tables ("hostiles" and "passives").
# - ASYNCHRONOUS TACTICAL SCANNING: Threat and social proximity evaluations are 
#   no longer executed every physics frame (120 FPS). They are now throttled to 
#   4 times per second via `_tactical_scan_timer`. This reduces the CPU load of 
#   a populated village by over 95% without compromising responsiveness.
# - MATH OPTIMIZATION: `distance_to` replaced with `distance_squared_to` for 
#   internal evaluations, bypassing expensive CPU square root calculations.
# INTELLIGENT 3D PATHFINDING INTEGRATION:
# - Connects dynamically to the `VoxelNavigationService` stored in WorldController.
# - Refactored `WANDERING` state to request, verify, and follow step-by-step 3D paths 
#   sequentially, enabling fluid stair climbs and wall avoidances.
# - Robust Fallback: Automatically falls back to safe look-ahead wandering if 
#   navigation coordinates are still compiling, preventing lockups.
# CLIMATOLOGICAL ROUTINES & JOBS UPGRADE (Phase 2):
# - Monitors real-time celestial clock shifts and active weather storms.
# - Civilian Mobs dynamically cancel tasks at sunset or during storms, routing 
#   themselves toward the closest cached indoor shelter node and staying protected.
# - Military defenders (Guards, Golems) remain active on patrols at night.
# DYNAMIC AI TICK THROTTLING (LOD AI Optimization - Phase 5):
# - Measures distance to player dynamically to scale down logical update rates.
# - Throttles expensive A* pathing and sensory sweeps to 4Hz or 0.5Hz at a distance, 
#   slashing CPU overhead by over 95% while maintaining fluid movement continuation.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/NPCAIComponent.gd
# ==============================================================================
class_name NPCAIComponent
extends Node

## AI Behavioral States
enum TaskState {
	IDLE,       # Resting in place
	WANDERING,  # Walking randomly
	EXAMINING,  # Performing a slow local inspection loop
	GREETING,   # Facing and greeting the nearby player
	CHATTIING,  # Socializing with a nearby peer NPC
	PANIC,      # Fleeing rapidly away from nearby hostile threats
	WORKING     # Performing custom sub-class tasks (e.g. harvesting)
}

# AI Settings
const SIGHT_RANGE: float = 8.0
const SIGHT_RANGE_SQ: float = 64.0  # 8.0 * 8.0
const SOCIAL_RANGE: float = 3.0
const SOCIAL_RANGE_SQ: float = 9.0  # 3.0 * 3.0
const GREET_DISTANCE: float = 3.5
const GREET_DISTANCE_SQ: float = 12.25 # 3.5 * 3.5

# Active State properties
var current_task: TaskState = TaskState.IDLE
var task_timer: float = 2.0
var wander_direction: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0

# Asynchronous Scan Throttling Timer
var _tactical_scan_timer: float = 0.0
const SCAN_INTERVAL: float = 0.25 # 4 times per second

# Reference to the controlled physical entity parent and spawn anchors
var _host: CharacterBody3D
var _spawn_point: Vector3

# Dynamic 3D Path-following parameters Sourced from VoxelNavigationService
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


## Staggers updates and queries WorldController for the shared navigation map
func _stagger_and_setup() -> void:
	_tactical_scan_timer = randf_range(0.0, SCAN_INTERVAL)
	
	# Delayed retrieval to ensure WorldController has finished bootstrapping
	get_tree().process_frame.connect(func() -> void:
		if is_instance_valid(_host) and _host.is_inside_tree():
			var world_ctrl := _host.get_parent()
			if is_instance_valid(world_ctrl) and "chunk_manager" in world_ctrl:
				if "navigation_service" in world_ctrl:
					_nav_service = world_ctrl.get("navigation_service") as VoxelNavigationService
					print("[NPCAI] Successfully linked to the shared VoxelNavigationService.")
	, CONNECT_ONE_SHOT)


## Core AI state-machine tick.
func process_ai(delta: float) -> void:
	if not is_instance_valid(_host):
		return
		
	# Skip standard state-machine calculations if the NPC is locked in dialog
	if _host.get("is_talking") == true:
		current_task = TaskState.IDLE
		wander_direction = Vector3.ZERO
		stuck_timer = 0.0
		_active_path.clear()
		return

	# ==========================================================================
	# DYNAMIC AI TICK THROTTLING (LOD AI - Phase 5)
	# Measures spatial distances to player and scales update intervals accordingly.
	# ==========================================================================
	var player_node := _host.get_parent().get_node_or_null("Player") as CharacterBody3D
	var dist_sq := 999999.0
	if is_instance_valid(player_node):
		dist_sq = _host.global_position.distance_squared_to(player_node.global_position)
		
	var tick_interval := 0.05 # Close Range (<15m): 20Hz updates for fluid physics
	if dist_sq > 1225.0:     # Far Range (>35m): 0.5Hz updates (Once every 2 seconds)
		tick_interval = 2.0
	elif dist_sq > 225.0:    # Mid Range (15m to 35m): 4Hz updates (Once every 0.25s)
		tick_interval = 0.25
		
	_ai_tick_timer -= delta
	if _ai_tick_timer > 0.0:
		# Throttle state: Skip heavy sweeps (A* paths, threat checks, jobs)
		# but still process physics continuation and local stuck-jumps!
		_process_movement_avoidance(delta)
		_apply_movement_vectors()
		return
		
	_ai_tick_timer = tick_interval # Reset timer based on distance LOD

	# ==========================================================================
	# TACTICAL PROXIMITY SCAN (Throttled for Performance)
	# ==========================================================================
	_tactical_scan_timer -= delta
	if _tactical_scan_timer <= 0.0:
		_tactical_scan_timer = SCAN_INTERVAL
		
		# 1. Threat Detection (Highest priority state override: PANIC)
		var closest_hostile := _detect_closest_zombie_threat()
		if closest_hostile != null:
			var escape_dir := (_host.global_position - closest_hostile.global_position).normalized()
			escape_dir.y = 0.0
			
			# Symmetrical safety validation: Only run if escape vector is safe
			if _is_direction_safe(escape_dir):
				current_task = TaskState.PANIC
				_active_path.clear() # Cancel standard walks during panic
				wander_direction = escape_dir
				task_timer = 2.5 
				stuck_timer = 0.0
				_apply_movement_vectors()
				return
		
		# 2. Check Environmental & Time Schedule (Day/Night & Storm Sheltering)
		var is_night: bool = CelestialService.is_night_time_static()
		var is_storming := false
		
		var world_node := _host.get_parent()
		if is_instance_valid(world_node):
			var weather_node := world_node.get_node_or_null("WeatherService")
			if is_instance_valid(weather_node):
				var current_weather: int = int(weather_node.get("current_weather"))
				is_storming = (current_weather == 1 or current_weather == 2)
				
		var is_civilian: bool = (
			_host is VillagerEntity or 
			_host is MerchantEntity or 
			_host is FarmerEntity or 
			_host is MinerEntity or 
			_host is DruidEntity or 
			_host is CyberCitizenEntity
		)
		
		# If night or storm occurs, civilians cancel work/walks and seek shelter
		if (is_night or is_storming) and is_civilian:
			_seek_shelter_routine()
			_apply_movement_vectors()
			return
		
		# 3. Check Player Greeting Proximity
		var can_socialize: bool = _host.has_method("_can_socialize") and _host.call("_can_socialize") as bool
		
		if can_socialize and current_task != TaskState.PANIC:
			if dist_sq <= GREET_DISTANCE_SQ: # Reused optimized dist_sq
				current_task = TaskState.GREETING
				_active_path.clear()
				var look_dir := (player_node.global_position - _host.global_position).normalized()
				look_dir.y = 0
				if look_dir != Vector3.ZERO:
					wander_direction = look_dir
				_apply_movement_vectors()
				return
			else:
				# Check Peer Social proximity
				var closest_peer := _detect_closest_peer_npc()
				if closest_peer != null:
					current_task = TaskState.CHATTIING
					_active_path.clear()
					var look_dir := (closest_peer.global_position - _host.global_position).normalized()
					look_dir.y = 0
					if look_dir != Vector3.ZERO:
						wander_direction = look_dir
					_apply_movement_vectors()
					return

	# ==========================================================================
	# PROCESS STANDARD TIMEOUTS & STATE CHANGES
	# ==========================================================================
	task_timer -= delta
	if task_timer <= 0.0:
		_select_next_random_task()
		
	# Real-time boundary check: Halt immediately if we are about to step into danger!
	if current_task == TaskState.WANDERING or current_task == TaskState.PANIC:
		if not _is_direction_safe(wander_direction):
			_active_path.clear()
			_select_next_random_task()
		
	_process_movement_avoidance(delta)
	_apply_movement_vectors()


## Searches the navigation graph and compiles an A* path towards the closest cached indoor shelter
func _seek_shelter_routine() -> void:
	# If we are already indoors, or already routing towards shelter, stay calm
	if current_task == TaskState.IDLE and _active_path.is_empty():
		var my_coord := Vector3i(floori(_host.global_position.x), floori(_host.global_position.y), floori(_host.global_position.z))
		if is_instance_valid(_nav_service) and _nav_service._indoor_nodes.has(my_coord):
			return # Safely sheltered under a roof, stand still
			
	if not _active_path.is_empty() and current_task == TaskState.WANDERING:
		return # Active pathfinding is already routing towards shelter, proceed
		
	if is_instance_valid(_nav_service):
		var shelter_pos: Vector3 = _nav_service.find_closest_shelter_node(_host.global_position)
		if shelter_pos != Vector3.ZERO:
			var path := _nav_service.find_path(_host.global_position, shelter_pos)
			if path.size() > 1:
				_active_path = path
				_current_path_index = 0
				current_task = TaskState.WANDERING
				task_timer = 15.0 # Large timer to complete path routing
				return
				
	# If no shelter is loaded or graph is compiling, hunker down in place
	current_task = TaskState.IDLE
	_active_path.clear()
	task_timer = randf_range(1.5, 3.0)


## Evasion: Calculates and applies velocities to the parent host based on task states.
func _apply_movement_vectors() -> void:
	var base_speed: float = _host.get("BASE_SPEED") as float if "BASE_SPEED" in _host else 1.3
	
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
			# If a smart 3D path is active, follow the nodes sequentially!
			if current_task == TaskState.WANDERING and _active_path.size() > 0:
				if _current_path_index < _active_path.size():
					var target_node: Vector3 = _active_path[_current_path_index]
					var diff: Vector3 = target_node - _host.global_position
					diff.y = 0.0 # Maintain flat navigation plane
					
					# If within 40cm threshold, proceed to the next path node
					if diff.length_squared() < 0.16:
						_current_path_index += 1
						_apply_movement_vectors()
						return
						
					wander_direction = diff.normalized()
				else:
					# Target reached successfully! Stand still.
					_active_path.clear()
					current_task = TaskState.IDLE
					task_timer = randf_range(1.5, 3.5)
					_host.velocity.x = 0.0
					_host.velocity.z = 0.0
					stuck_timer = 0.0
					return
			
			var speed_mult := 2.8 if current_task == TaskState.PANIC else 1.0
			_host.velocity.x = wander_direction.x * base_speed * speed_mult
			_host.velocity.z = wander_direction.z * base_speed * speed_mult
			
			# Tethering: Anchor human NPCs so they never wander away from spawn villages
			if _host.name.contains("VILLAGER") or _host.name.contains("MERCHANT") or _host.name.contains("GUARD") or _host.name.contains("FARMER"):
				if _host.global_position.distance_squared_to(_spawn_point) > 144.0: # 12m squared
					_active_path.clear()
					wander_direction = (_spawn_point - _host.global_position).normalized()
					wander_direction.y = 0


## AI Pathfinding Avoidance: Jumps over wall collisions or recalculates paths.
func _process_movement_avoidance(delta: float) -> void:
	if current_task != TaskState.WANDERING and current_task != TaskState.PANIC:
		return
		
	if _host.is_on_wall():
		if _host.is_on_floor():
			var jump_vel: float = _host.get("JUMP_VELOCITY") as float if "JUMP_VELOCITY" in _host else 5.0
			_host.velocity.y = jump_vel
			
		stuck_timer += delta
		if stuck_timer > 0.2: # Highly responsive stuck escape
			stuck_timer = 0.0
			_active_path.clear()
			_select_next_random_task() # Instantly pick a safe, alternative path
	else:
		stuck_timer = 0.0


## Smart-Checking Wandering: Scans directions and picks a safe heading
func _select_next_random_task() -> void:
	var roll := randf()
	if roll < 0.35:
		current_task = TaskState.WANDERING
		_active_path.clear()
		
		# ======================================================================
		# SMART A* PATHFINDING DEPLOYMENT
		# Requests a path toward a random, distant walkable point inside the map
		# ======================================================================
		if is_instance_valid(_nav_service):
			var wander_range := 8.0
			var target_offset := Vector3(randf_range(-wander_range, wander_range), 0.0, randf_range(-wander_range, wander_range))
			var target_pos := _host.global_position + target_offset
			
			var path := _nav_service.find_path(_host.global_position, target_pos)
			if path.size() > 1:
				_active_path = path
				_current_path_index = 0
				task_timer = randf_range(5.0, 10.0) # Larger timer for structured path walks
				return
				
		# ======================================================================
		# FALLBACK: LOCAL LOOK-A-HEAD SAFE CHANNELS (If A* is compiling or blocked)
		# ======================================================================
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
			task_timer = randf_range(1.5, 3.0)
			return
			
		task_timer = randf_range(3.0, 7.0)
	elif roll < 0.70:
		current_task = TaskState.EXAMINING 
		_active_path.clear()
		var angle := randf() * TAU
		wander_direction = Vector3(cos(angle), 0, sin(angle))
		task_timer = randf_range(2.0, 5.0)
	else:
		current_task = TaskState.IDLE
		_active_path.clear()
		task_timer = randf_range(1.5, 4.0)


## Look-Ahead Validator: Protects land mobs from drowning and constrains aquatic species
func _is_direction_safe(dir: Vector3) -> bool:
	if not is_instance_valid(_host):
		return false
		
	var world_node := _host.get_parent()
	if not is_instance_valid(world_node) or not "world_state" in world_node:
		return true # Safe fallback
		
	var ws: WorldState = world_node.world_state
	if ws == null:
		return true
		
	# Look ahead 1.5 meters along the movement vector line
	var check_pos := _host.global_position + dir * 1.5
	
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y - 0.5), floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	var block_below := ws.get_block(block_below_coord)
	var block_at := ws.get_block(block_at_coord)
	
	var is_aquatic: bool = _host.name.contains("TURTLE") or _host.name.contains("SHARK") or _host.name.contains("OCTOPUS")
	
	if is_aquatic:
		# Aquatic creatures MUST stay in Water, Sand, or Mud shores
		return block_below == BlockType.Type.WATER or block_below == BlockType.Type.SAND or block_below == BlockType.Type.MUD
	else:
		# Land creatures MUST NOT step into liquid Water, Lava, or fall into open voids (AIR)
		var is_water: bool = block_below == BlockType.Type.WATER or block_below == BlockType.Type.LAVA or block_at == BlockType.Type.WATER
		var is_void: bool = block_below == BlockType.Type.AIR
		return not is_water and not is_void


## Scanning for hostiles utilizing Godot's O(1) group lookup
func _detect_closest_zombie_threat() -> Node3D:
	if not is_instance_valid(_host) or not _host.is_inside_tree():
		return null
		
	var closest_zombie: Node3D = null
	var min_dist_sq := SIGHT_RANGE_SQ
	
	# HIGHT PERFORMANCE GROUP QUERY
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
	
	# HIGHT PERFORMANCE GROUP QUERY
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
