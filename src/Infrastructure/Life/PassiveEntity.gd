# ==============================================================================
# Project: CraftDomain
# Description: Abstract base class representing a physics-bound passive entity (NPC/Fauna).
#              Schedules procedural walk cycles, spatial state-machines, and variety.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Serves as a robust base 
#                contract with safe default virtual values for subclasses.
#              - Single Responsibility Principle (SRP): Isolates base movement 
#                physics, pathfinding, and visual variation routines.
#              AI OVERHAUL & LOCALIZATION:
#              - Added coordinate-based deterministic variant rendering (No two identical NPCs).
#              - Added dynamic threat-detection to trigger fleeing behaviors.
#              - Added social peer detection for greeting/chatting routines.
#              - REFACTORING: Replaced hardcoded speech bubble text with dynamic 
#                i18n translation keys (BUBBLE_TALK, BUBBLE_TRADE, BUBBLE_FARMER).
#              CONVERSATION LOCK UPGRADE:
#              - Added start_talking() and stop_talking() states with dynamic 
#                real-time gaze slerp targeting to prevent walking away during dialogues.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/PassiveEntity.gd
# ==============================================================================
class_name PassiveEntity
extends CharacterBody3D

## Structural Behavioral AI States
enum TaskState {
	IDLE,       # Resting in place, slow breathing
	WANDERING,  # Walking randomly
	EXAMINING,  # Performing a slow inspection loop facing a block
	GREETING,   # Stop to face and greet the nearby player
	CHATTIING,  # Stop to socialize with a nearby peer NPC
	PANIC,      # Fleeing rapidly away from nearby hostile threats
	WORKING     # Custom pathfinding managed by subclasses (e.g., Farmers harvesting)
}

# Base physics movement constants
const BASE_SPEED: float = 1.3
const JUMP_VELOCITY: float = 5.0
const SIGHT_RANGE: float = 8.0 # Threat detection radius
const SOCIAL_RANGE: float = 3.0 # Peer interaction radius

# Dependencies
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Domain Model Composition (DDD)
var domain_entity: VoxelEntity

# Behavior State Machine properties
var current_task: TaskState = TaskState.IDLE
var _task_timer: float = 2.0
var _wander_direction: Vector3 = Vector3.ZERO
var _animation_time: float = 0.0

# original Spawn Point used to anchor human NPCs so they never get lost (Tethering)
var _spawn_point: Vector3

# AI Obstacle Avoidance Tracker
var _stuck_timer: float = 0.0

# Dynamic Node references for subclass procedural animations
var _visual_root: Node3D
var _body_bob_node: Node3D 
var _head_node: Node3D
var _arms_node: Node3D
var _left_eye: MeshInstance3D
var _right_eye: MeshInstance3D

# Dynamic floating Speech Bubble reference
var _bubble: Node3D
var _quest_check_timer: float = 0.5

# Procedural blinking trackers
var _blink_timer: float = randf_range(2.0, 5.0)
var _blink_duration: float = 0.0
var _is_blinking: bool = false

# Player tracking range
const GREET_DISTANCE: float = 3.5

# ==============================================================================
# VARIANT SYSTEM: Deterministic procedural aesthetic configurations
# ==============================================================================
var npc_seed: int = 0
var variant_skin_color: Color
var variant_clothing_color: Color
var variant_hair_color: Color
var variant_height_scale: float = 1.0

# ==============================================================================
# CONVERSATION STATE MACHINE: Dynamic player gaze-lock variables
# ==============================================================================
var is_talking: bool = false
var _talking_partner: CharacterBody3D = null


func _init(spawn_pos: Vector3, initial_health: int = 1) -> void:
	position = spawn_pos
	_spawn_point = spawn_pos
	
	# Compute a deterministic seed based on coordinate hashes (stable on reloading)
	npc_seed = abs(int(spawn_pos.x * 73856093) ^ int(spawn_pos.z * 19349663))
	_generate_procedural_variant_palette()
	
	domain_entity = VoxelEntity.new(initial_health)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)


func _ready() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "Visuals"
	add_child(_visual_root)
	
	_body_bob_node = Node3D.new()
	_body_bob_node.name = "BodyBobJoint"
	_visual_root.add_child(_body_bob_node)
	
	_build_visual_representation()
	_setup_floating_bubble()
	
	# Apply the procedural variant height scale to the visual mesh
	_visual_root.scale = Vector3(1.0, variant_height_scale, 1.0)
	
	var col := CollisionShape3D.new()
	col.name = "EntityCollider"
	var box_shape := BoxShape3D.new()
	box_shape.size = _get_collision_box_size() * Vector3(1.0, variant_height_scale, 1.0)
	col.shape = box_shape
	col.position = _get_collision_box_position() * variant_height_scale
	add_child(col)


## Generates a unique, stable color palette using the deterministic coordinate seed.
func _generate_procedural_variant_palette() -> void:
	var generator := RandomNumberGenerator.new()
	generator.seed = npc_seed
	
	# 1. Procedural Skin Tones (Beige, warm peachy, tanned, olive)
	var skins = [
		Color(0.95, 0.75, 0.65), # Peach
		Color(0.85, 0.65, 0.55), # Tanned
		Color(0.92, 0.70, 0.58), # Light olive
		Color(0.65, 0.45, 0.35)  # Brown
	]
	variant_skin_color = skins[generator.randi() % skins.size()]
	
	# 2. Procedural Clothing Tones
	var clothes = [
		Color(0.35, 0.22, 0.15), # Classic Brown
		Color(0.20, 0.32, 0.45), # Slate Blue
		Color(0.25, 0.45, 0.28), # Forest Green
		Color(0.50, 0.22, 0.20), # Crimson
		Color(0.42, 0.32, 0.48)  # Purple
	]
	variant_clothing_color = clothes[generator.randi() % clothes.size()]
	
	# 3. Procedural Hair Tones (Brown, black, blonde, ginger)
	var hairs = [
		Color(0.18, 0.12, 0.08), # Dark Brown
		Color(0.08, 0.08, 0.08), # Charcoal Black
		Color(0.82, 0.68, 0.32), # Golden Blonde
		Color(0.72, 0.35, 0.12)  # Ginger Red
	]
	variant_hair_color = hairs[generator.randi() % hairs.size()]
	
	# 4. Height scaling variance (Slightly taller or shorter)
	variant_height_scale = generator.randf_range(0.92, 1.08)


func _build_visual_representation() -> void:
	assert(false, "[PassiveEntity] _build_visual_representation() must be implemented by concrete subclass.")


## Virtual Fallback: Returns a default 3D collision box size if not overridden.
func _get_collision_box_size() -> Vector3:
	return Vector3(0.6, 0.8, 0.6)


## Virtual Fallback: Returns a default 3D collision box height offset if not overridden.
func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.4, 0.0)


func _setup_floating_bubble() -> void:
	pass


func interact(_player: CharacterBody3D) -> void:
	pass


# ==============================================================================
# CONVERSATION LIFECYCLE: Freeze movement and enable player gaze-lock
# ==============================================================================

## Locks the NPC, freezing physical velocity and assigning the conversational partner.
func start_talking(partner: CharacterBody3D) -> void:
	is_talking = true
	_talking_partner = partner
	
	# Freeze physical velocities instantly
	velocity = Vector3.ZERO


## Unlocks the NPC and resumes standard autonomous wandering routines.
func stop_talking() -> void:
	is_talking = false
	_talking_partner = null
	
	# Force a direct reset of state timers to prevent lingering animations
	_select_next_random_task()


func _create_box(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_pos
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic_specular = 0.0 
	mesh_instance.material_override = mat
	
	parent.add_child(mesh_instance)
	return mesh_instance


func take_damage(amount: int, knockback_force: Vector3) -> void:
	if domain_entity.is_dead: return
	
	# Force release talk states if NPC takes damage (e.g., hit by zombi during talk)
	if is_talking:
		stop_talking()
		
	velocity += knockback_force
	domain_entity.take_damage(amount)


func _on_domain_entity_took_damage(_amount: int) -> void:
	velocity.y = JUMP_VELOCITY
	
	# Panic!
	current_task = TaskState.PANIC
	_task_timer = randf_range(3.0, 5.0)
	var angle := randf() * TAU
	_wander_direction = Vector3(cos(angle), 0, sin(angle))


func _on_domain_entity_died() -> void:
	_try_drop_player_loot()
	queue_free()


func _try_drop_player_loot() -> void:
	var parent := get_parent()
	if is_instance_valid(parent):
		var player_node := parent.get_node_or_null("Player") as CharacterBody3D
		if is_instance_valid(player_node):
			var inv: IInventory = player_node.get("inventory")
			if is_instance_valid(inv):
				_drop_loot(inv)
				player_node.call("_sync_hud_counters") 


func _drop_loot(_inv: IInventory) -> void:
	pass


func _physics_process(delta: float) -> void:
	if domain_entity.is_dead: return
		
	if not is_on_floor():
		velocity.y -= gravity * delta

	_process_blinking_cycle(delta)
	_process_ai_state_machine(delta)
	_process_procedural_animations(delta)
	
	# Quest tracking updates
	_quest_check_timer -= delta
	if _quest_check_timer <= 0.0:
		_quest_check_timer = 0.5
		_update_quest_bubble_state()

	move_and_slide()


## Updates the floating speech bubble using dynamic translation keys.
func _update_quest_bubble_state() -> void:
	if not is_instance_valid(_bubble):
		return
		
	var active_q := QuestService.get_active_quest()
	if active_q != null:
		var is_target := false
		if active_q.quest_id == "lost_bazaar" and name.contains("VILLAGER"):
			is_target = true
		elif active_q.quest_id == "fuel_fryer" and name.contains("MERCHANT"):
			is_target = true
		elif active_q.quest_id == "plains_defender" and name.contains("GUARD"):
			is_target = true
			
		if is_target:
			# Fully localized dynamic quest title bubble!
			_bubble.call("set_text", "⭐ [ " + tr("BUBBLE_ACTIVE_MISSION").to_upper() + ": " + tr(active_q.title).to_upper() + " ] ⭐")
			return
			
	if name.contains("VILLAGER"):
		_bubble.call("set_text", tr("BUBBLE_TALK"))
	elif name.contains("MERCHANT"):
		_bubble.call("set_text", tr("BUBBLE_TRADE"))
	elif name.contains("GUARD"):
		_bubble.call("set_text", tr("BUBBLE_TALK"))
	elif name.contains("FARMER"):
		_bubble.call("set_text", tr("BUBBLE_FARMER"))


func _process_blinking_cycle(delta: float) -> void:
	if not _is_blinking:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_is_blinking = true
			_blink_duration = 0.12 
			_set_eyes_vertical_scale(0.1) 
	else:
		_blink_duration -= delta
		if _blink_duration <= 0.0:
			_is_blinking = false
			_blink_timer = randf_range(2.5, 6.0)
			_set_eyes_vertical_scale(1.0) 


func _set_eyes_vertical_scale(y_scale: float) -> void:
	if is_instance_valid(_left_eye):
		_left_eye.scale.y = y_scale
	if is_instance_valid(_right_eye):
		_right_eye.scale.y = y_scale


func _process_ai_state_machine(delta: float) -> void:
	# If currently locked in conversation, freeze completely and skip normal state ticks
	if is_talking:
		velocity.x = 0.0
		velocity.z = 0.0
		_stuck_timer = 0.0
		return

	# 1. CORE AI ROUTINE: SIGHT & THREAT SENSING
	var closest_hostile: Node3D = _detect_closest_zombie_threat()
	if closest_hostile != null:
		current_task = TaskState.PANIC
		_wander_direction = (global_position - closest_hostile.global_position).normalized()
		_wander_direction.y = 0.0
		_task_timer = 2.5 # Extend panic timeline
		_stuck_timer = 0.0
	
	# 2. GREET PLAYER ROUTINE
	var player_node := get_parent().get_node_or_null("Player") as CharacterBody3D
	var distance_to_player: float = 999.0
	if is_instance_valid(player_node):
		distance_to_player = global_position.distance_to(player_node.global_position)
		
	var can_socialize := _can_socialize()
	
	if can_socialize and current_task != TaskState.PANIC:
		if distance_to_player <= GREET_DISTANCE:
			current_task = TaskState.GREETING
			var look_dir := (player_node.global_position - global_position).normalized()
			look_dir.y = 0
			if look_dir != Vector3.ZERO:
				_wander_direction = look_dir
		else:
			# 3. PEER SOCIALIZATION SENSING
			var closest_peer := _detect_closest_peer_npc()
			if closest_peer != null:
				current_task = TaskState.CHATTIING
				var look_dir := (closest_peer.global_position - global_position).normalized()
				look_dir.y = 0
				if look_dir != Vector3.ZERO:
					_wander_direction = look_dir
			else:
				# Tick state timer
				_task_timer -= delta
				if _task_timer <= 0.0:
					_select_next_random_task()
	elif not can_socialize and current_task != TaskState.PANIC:
		_task_timer -= delta
		if _task_timer <= 0.0:
			_select_next_random_task()

	# 4. PATHFINDING MOTION
	match current_task:
		TaskState.IDLE, TaskState.GREETING, TaskState.CHATTIING:
			velocity.x = move_toward(velocity.x, 0, BASE_SPEED)
			velocity.z = move_toward(velocity.z, 0, BASE_SPEED)
			_stuck_timer = 0.0
			
		TaskState.EXAMINING:
			velocity.x = _wander_direction.x * (BASE_SPEED * 0.25)
			velocity.z = _wander_direction.z * (BASE_SPEED * 0.25)
			_stuck_timer = 0.0
			
		TaskState.WANDERING, TaskState.PANIC:
			var speed_mult := 2.8 if current_task == TaskState.PANIC else 1.0
			velocity.x = _wander_direction.x * BASE_SPEED * speed_mult
			velocity.z = _wander_direction.z * BASE_SPEED * speed_mult
			
			var is_human: bool = name.contains("VILLAGER") or name.contains("MERCHANT") or name.contains("GUARD") or name.contains("FARMER")
			if is_human and global_position.distance_to(_spawn_point) > 12.0:
				_wander_direction = (_spawn_point - global_position).normalized()
				_wander_direction.y = 0
			
			# INTELLIGENT WALL JUMPING & AVOIDANCE
			if is_on_wall():
				if is_on_floor():
					velocity.y = JUMP_VELOCITY 
					
				_stuck_timer += delta
				if _stuck_timer > 0.4: 
					_stuck_timer = 0.0
					var wall_normal := get_wall_normal()
					var flat_normal := Vector3(wall_normal.x, 0, wall_normal.z).normalized()
					
					if flat_normal != Vector3.ZERO:
						_wander_direction = _wander_direction.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.4, 0.4)).normalized()
					else:
						var angle := randf() * TAU
						_wander_direction = Vector3(cos(angle), 0, sin(angle))
			else:
				_stuck_timer = 0.0
				
		TaskState.WORKING:
			pass 


func _can_socialize() -> bool:
	return false


## Scans the parent node lists for nearby zombies (hostiles) to trigger fleeing states.
func _detect_closest_zombie_threat() -> Node3D:
	var world_node := get_parent()
	if not is_instance_valid(world_node):
		return null
		
	var closest_zombie: Node3D = null
	var min_dist := SIGHT_RANGE
	
	for child in world_node.get_children():
		if child.name.contains("ZOMBIE") and is_instance_valid(child) and not child.get("domain_entity").is_dead:
			var dist := global_position.distance_to(child.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_zombie = child
				
	return closest_zombie


## Scans for other idle passive entities to start a socialization greet.
func _detect_closest_peer_npc() -> Node3D:
	var world_node := get_parent()
	if not is_instance_valid(world_node):
		return null
		
	var closest_peer: Node3D = null
	var min_dist := SOCIAL_RANGE
	
	for child in world_node.get_children():
		if child != self and child is PassiveEntity and is_instance_valid(child):
			# Only socialize if the peer is also standing idle
			var peer_state: TaskState = child.get("current_task")
			if peer_state == TaskState.IDLE or peer_state == TaskState.CHATTIING:
				var dist := global_position.distance_to(child.global_position)
				if dist < min_dist:
					min_dist = dist
					closest_peer = child
					
	return closest_peer


func _select_next_random_task() -> void:
	var roll := randf()
	if roll < 0.35:
		current_task = TaskState.WANDERING
		var angle := randf() * TAU
		_wander_direction = Vector3(cos(angle), 0, sin(angle))
		_task_timer = randf_range(3.0, 7.0)
	elif roll < 0.70:
		current_task = TaskState.EXAMINING 
		var angle := randf() * TAU
		_wander_direction = Vector3(cos(angle), 0, sin(angle))
		_task_timer = randf_range(2.0, 5.0)
	else:
		current_task = TaskState.IDLE
		_task_timer = randf_range(1.5, 4.0)


func _process_procedural_animations(delta: float) -> void:
	_animation_time += delta
	var is_moving: bool = current_task == TaskState.WANDERING or current_task == TaskState.PANIC or current_task == TaskState.WORKING
	
	# If talking, force the visual root to lock gaze directly on the talking partner
	if is_talking and is_instance_valid(_talking_partner):
		var look_dir := (_talking_partner.global_position - global_position).normalized()
		look_dir.y = 0.0
		if look_dir.length_squared() > 0.01:
			var target_look := global_position + look_dir
			_visual_root.look_at(target_look, Vector3.UP)
			_visual_root.rotation.x = 0
			_visual_root.rotation.z = 0
	elif is_instance_valid(_visual_root) and _wander_direction.length_squared() > 0.05:
		var target_look := global_position + _wander_direction
		_visual_root.look_at(target_look, Vector3.UP)
		_visual_root.rotation.x = 0
		_visual_root.rotation.z = 0
		
	if is_instance_valid(_body_bob_node):
		if is_moving and is_on_floor() and not is_talking:
			var speed_mult := 18.0 if current_task == TaskState.PANIC else (12.0 if _is_avian() else 10.0)
			var bounce_height := 0.05 if _is_avian() else 0.035
			_body_bob_node.position.y = abs(sin(_animation_time * speed_mult)) * bounce_height
		else:
			_body_bob_node.position.y = lerp(_body_bob_node.position.y, sin(_animation_time * 2.0) * 0.015, delta * 5.0)
			
	if current_task == TaskState.GREETING or current_task == TaskState.CHATTIING or is_talking:
		if is_instance_valid(_head_node):
			# Noding head up/down procedural loop to simulate talking!
			_head_node.rotation.x = sin(_animation_time * 6.0) * 0.15 
			_head_node.rotation.y = 0.0
		if is_instance_valid(_arms_node):
			_arms_node.rotation.x = 0.0
			_arms_node.position.y = -0.21
			
	elif current_task == TaskState.EXAMINING:
		if is_instance_valid(_head_node):
			_head_node.rotation.x = lerp(_head_node.rotation.x, deg_to_rad(25), delta * 5.0)
			_head_node.rotation.y = sin(_animation_time * 2.0) * 0.05
		if is_instance_valid(_arms_node):
			_arms_node.rotation.x = sin(_animation_time * 8.0) * 0.15
			_arms_node.position.y = -0.21 + sin(_animation_time * 8.0) * 0.03
			
	elif is_moving:
		var speed_mult := 12.0 if current_task == TaskState.PANIC else (8.0 if _is_avian() else 5.0)
		var sway_amount := 0.2 if _is_avian() else 0.08
		
		if is_instance_valid(_head_node):
			_head_node.rotation.x = sin(_animation_time * speed_mult) * sway_amount
			_head_node.rotation.y = cos(_animation_time * (speed_mult * 0.5)) * 0.05
			
		if is_instance_valid(_arms_node):
			_arms_node.rotation.x = cos(_animation_time * speed_mult) * 0.1
			_arms_node.position.y = -0.21 + sin(_animation_time * 10.0) * 0.02
			
	else: 
		if is_instance_valid(_head_node):
			_head_node.rotation.x = lerp(_head_node.rotation.x, 0.0, delta * 5.0)
			_head_node.rotation.y = lerp(_head_node.rotation.y, 0.0, delta * 5.0)
		if is_instance_valid(_arms_node):
			_arms_node.rotation.x = lerp(_arms_node.rotation.x, 0.0, delta * 5.0)
			_arms_node.position.y = lerp(_arms_node.position.y, -0.21, delta * 5.0)


func _is_avian() -> bool:
	return false
