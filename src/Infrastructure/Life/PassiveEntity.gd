# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive entity.
#              UX IMPROVED: Upgraded NPC sizes (1.15x), programmed 3D blinking eyes,
#              smooth organic walk cycles, and dynamic farming/greeting behaviors.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/PassiveEntity.gd
# ==============================================================================
class_name PassiveEntity
extends CharacterBody3D

## Entity Type definitions.
enum Type {
	PIG,
	CHICKEN,
	VILLAGER,
	MERCHANT
}

## Behavioral Task States
enum TaskState {
	IDLE,       # Resting in place
	WANDERING,  # Walking randomly
	EXAMINING,  # Performing a farming/inspecting work loop on a block
	GREETING    # Stopping to look at and nod to the nearby player
}

# Physics movement properties
const BASE_SPEED: float = 1.3
const JUMP_VELOCITY: float = 5.0

# Dependencies
var entity_type: Type
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Domain Model Composition (DDD)
var domain_entity: VoxelEntity

# Behavior State Machine properties
var current_task: TaskState = TaskState.IDLE
var _task_timer: float = 2.0
var _wander_direction: Vector3 = Vector3.ZERO
var _animation_time: float = 0.0

# Dynamic Node references for procedural animations
var _visual_root: Node3D
var _head_node: Node3D
var _arms_node: Node3D
var _left_eye: MeshInstance3D
var _right_eye: MeshInstance3D

# Procedural blinking trackers
var _blink_timer: float = randf_range(2.0, 5.0)
var _blink_duration: float = 0.0
var _is_blinking: bool = false

# Player tracking range
const GREET_DISTANCE: float = 3.5

func _init(p_type: Type, spawn_pos: Vector3) -> void:
	entity_type = p_type
	position = spawn_pos
	name = "Entity_%s" % Type.keys()[entity_type]
	
	# Instantiate pure domain model (Passive entities have 1 health)
	domain_entity = VoxelEntity.new(1)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)

func _ready() -> void:
	_build_visual_representation()
	_setup_collision()

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "EntityCollider"
	var box_shape := BoxShape3D.new()
	
	# Scaled collision boundaries (1.15x larger)
	match entity_type:
		Type.CHICKEN:
			box_shape.size = Vector3(0.46, 0.69, 0.46)
			col.position = Vector3(0, 0.345, 0)
		Type.PIG:
			box_shape.size = Vector3(0.69, 0.69, 0.92)
			col.position = Vector3(0, 0.345, 0)
		Type.VILLAGER, Type.MERCHANT:
			box_shape.size = Vector3(0.575, 1.61, 0.575)
			col.position = Vector3(0, 0.805, 0)
			
	col.shape = box_shape
	add_child(col)

func _build_visual_representation() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "Visuals"
	add_child(_visual_root)
	
	match entity_type:
		Type.PIG:
			_create_box(_visual_root, Vector3(0.7, 0.45, 0.9), Vector3(0, 0.35, 0), Color(1.0, 0.62, 0.72)) # Torso
			
			_head_node = Node3D.new()
			_head_node.name = "PigHead"
			_head_node.position = Vector3(0, 0.6, -0.45)
			_visual_root.add_child(_head_node)
			
			_create_box(_head_node, Vector3(0.4, 0.4, 0.4), Vector3(0, 0, 0), Color(1.0, 0.58, 0.68)) # Head
			_create_box(_head_node, Vector3(0.22, 0.12, 0.12), Vector3(0, -0.1, -0.22), Color(0.92, 0.38, 0.48)) # Snout
			
			# Voxel pig eyes with blinking
			_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.16, 0.05, -0.21), Color.WHITE)
			_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15)) # Pupil
			
			_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.16, 0.05, -0.21), Color.WHITE)
			_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15))
			
			# Legs
			_create_box(_visual_root, Vector3(0.18, 0.3, 0.18), Vector3(-0.22, 0.15, -0.28), Color(1.0, 0.62, 0.72))
			_create_box(_visual_root, Vector3(0.18, 0.3, 0.18), Vector3(0.22, 0.15, -0.28), Color(1.0, 0.62, 0.72))
			_create_box(_visual_root, Vector3(0.18, 0.3, 0.18), Vector3(-0.22, 0.15, 0.28), Color(1.0, 0.62, 0.72))
			_create_box(_visual_root, Vector3(0.18, 0.3, 0.18), Vector3(0.22, 0.15, 0.28), Color(1.0, 0.62, 0.72))
			
		Type.CHICKEN:
			_create_box(_visual_root, Vector3(0.35, 0.35, 0.45), Vector3(0, 0.35, 0), Color(0.98, 0.98, 0.98)) # Body
			
			_head_node = Node3D.new()
			_head_node.name = "ChickenHead"
			_head_node.position = Vector3(0, 0.58, -0.22)
			_visual_root.add_child(_head_node)
			
			_create_box(_head_node, Vector3(0.2, 0.25, 0.2), Vector3(0, 0, 0), Color(0.98, 0.98, 0.98)) # Head
			_create_box(_head_node, Vector3(0.18, 0.09, 0.14), Vector3(0, 0, -0.13), Color(1.0, 0.62, 0.0)) # Beak
			_create_box(_head_node, Vector3(0.08, 0.12, 0.08), Vector3(0, -0.12, -0.05), Color(0.92, 0.1, 0.1)) # Wattle
			
			# Blinking Chicken Eyes
			_left_eye = _create_box(_head_node, Vector3(0.06, 0.06, 0.02), Vector3(-0.08, 0.05, -0.11), Color.WHITE)
			_create_box(_left_eye, Vector3(0.03, 0.03, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15))
			
			_right_eye = _create_box(_head_node, Vector3(0.06, 0.06, 0.02), Vector3(0.08, 0.05, -0.11), Color.WHITE)
			_create_box(_right_eye, Vector3(0.03, 0.03, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15))
			
			# Legs
			_create_box(_visual_root, Vector3(0.06, 0.18, 0.06), Vector3(-0.09, 0.09, 0), Color(1.0, 0.62, 0.0))
			_create_box(_visual_root, Vector3(0.06, 0.18, 0.06), Vector3(0.09, 0.09, 0), Color(1.0, 0.62, 0.0))
			
		Type.VILLAGER, Type.MERCHANT:
			var robe_color := Color(0.35, 0.22, 0.15) if entity_type == Type.VILLAGER else Color(0.48, 0.16, 0.65)
			var apron_color := Color(0.25, 0.15, 0.1) if entity_type == Type.VILLAGER else Color(0.85, 0.6, 0.15)
			
			# 1. Torso Robe (Scaled up 1.15x)
			_create_box(_visual_root, Vector3(0.52, 1.05, 0.52), Vector3(0, 0.64, 0), robe_color)
			
			# 2. Standalone Head Node
			_head_node = Node3D.new()
			_head_node.name = "HumanHead"
			_head_node.position = Vector3(0, 1.25, 0)
			_visual_root.add_child(_head_node)
			
			_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.05, 0), Color(0.95, 0.75, 0.65)) # Head skin
			_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, -0.01, -0.21), Color(0.85, 0.65, 0.55)) # Classic Nose
			
			# 3D detailed blinking Eyes
			_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.06, -0.18), Color.WHITE)
			_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.18, 0.42, 0.68) if entity_type == Type.MERCHANT else Color(0.2, 0.2, 0.2)) # Pupil
			
			_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.06, -0.18), Color.WHITE)
			_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.18, 0.42, 0.68) if entity_type == Type.MERCHANT else Color(0.2, 0.2, 0.2))
			
			# 3. Arms (Node created independently to swing/move organically)
			_arms_node = Node3D.new()
			_arms_node.name = "ArmsJoint"
			_arms_node.position = Vector3(0, 0.75, -0.21)
			_visual_root.add_child(_arms_node)
			_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), apron_color) # Folded arms block

func _create_box(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_pos
	
	var mat := ORMMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh_instance.material_override = mat
	
	parent.add_child(mesh_instance)
	return mesh_instance

func take_damage(amount: int, knockback_force: Vector3) -> void:
	if domain_entity.is_dead: return
	velocity += knockback_force
	domain_entity.take_damage(amount)

func _on_domain_entity_took_damage(_amount: int) -> void:
	velocity.y = JUMP_VELOCITY

func _on_domain_entity_died() -> void:
	queue_free()

## Merchant Trading Interaction handler
func interact(player: CharacterBody3D) -> void:
	if entity_type != Type.MERCHANT: return
		
	# Instantly pivot to face the player during a transaction
	var look_dir := (player.global_position - global_position).normalized()
	look_dir.y = 0
	if is_instance_valid(_visual_root) and look_dir != Vector3.ZERO:
		_visual_root.look_at(global_position + look_dir, Vector3.UP)

	var inventory: IInventory = player.get("inventory") as IInventory
	var player_hud = player.get("hud")
	var active_slot: int = player.get("active_slot_index")
	
	if is_instance_valid(inventory) and is_instance_valid(player_hud):
		if active_slot == 5: # Lava Bucket
			if TradingService.execute_trade(inventory, 5, 1, 6, 1):
				velocity.y = JUMP_VELOCITY # Excited hop!
				player_hud.call("update_active_slot", 5)
				print("[Merchant] Hmmm! Hot lava! Thank you! Here is your famous Lava-Fried Chicken!")
			else:
				print("[Merchant] Hmmm? You are out of Lava Buckets!")
		else:
			print("[Merchant] Hmmm? Bring me a Bucket of Lava (Slot 5) to trade for my Lava Fried Chicken!")

func _physics_process(delta: float) -> void:
	if domain_entity.is_dead: return
		
	# Apply standard physics gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	_process_blinking_cycle(delta)
	_process_ai_state_machine(delta)
	_process_procedural_animations(delta)

	move_and_slide()

## Temporarily shrinks the eyes vertically to simulate natural blinking
func _process_blinking_cycle(delta: float) -> void:
	if not _is_blinking:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_is_blinking = true
			_blink_duration = 0.12 # Blink lasts 120ms
			_set_eyes_vertical_scale(0.1) # Close eyes
	else:
		_blink_duration -= delta
		if _blink_duration <= 0.0:
			_is_blinking = false
			_blink_timer = randf_range(2.5, 6.0)
			_set_eyes_vertical_scale(1.0) # Open eyes

func _set_eyes_vertical_scale(y_scale: float) -> void:
	if is_instance_valid(_left_eye):
		_left_eye.scale.y = y_scale
	if is_instance_valid(_right_eye):
		_right_eye.scale.y = y_scale

## Advanced behavior states: WANDERING, GREETING players, or EXAMINING (working on grass)
func _process_ai_state_machine(delta: float) -> void:
	# 1. Proximity checking: if player is very close, Villagers/Merchants stop and greet them
	var player_node: CharacterBody3D = get_parent().get_node_or_null("Player") as CharacterBody3D
	var distance_to_player: float = 999.0
	
	if is_instance_valid(player_node):
		distance_to_player = global_position.distance_to(player_node.global_position)
		
	var can_socialize := (entity_type == Type.VILLAGER or entity_type == Type.MERCHANT)
	
	if can_socialize and distance_to_player <= GREET_DISTANCE:
		current_task = TaskState.GREETING
		# Rotate smoothly to look at the player
		var look_dir := (player_node.global_position - global_position).normalized()
		look_dir.y = 0
		if look_dir != Vector3.ZERO:
			_wander_direction = look_dir
	else:
		# Standard self-directed routine timers
		_task_timer -= delta
		if _task_timer <= 0.0:
			_select_next_random_task()

	# 2. Execute active state velocities
	match current_task:
		TaskState.IDLE, TaskState.GREETING:
			velocity.x = move_toward(velocity.x, 0, BASE_SPEED)
			velocity.z = move_toward(velocity.z, 0, BASE_SPEED)
			
		TaskState.EXAMINING:
			# Slow movement, looking down at a block
			velocity.x = _wander_direction.x * (BASE_SPEED * 0.25)
			velocity.z = _wander_direction.z * (BASE_SPEED * 0.25)
			
		TaskState.WANDERING:
			velocity.x = _wander_direction.x * BASE_SPEED
			velocity.z = _wander_direction.z * BASE_SPEED
			
			# Auto-jump over blocks when hitting a wall
			if is_on_wall() and is_on_floor():
				velocity.y = JUMP_VELOCITY

## Dynamically changes states to break robotic uniformity
func _select_next_random_task() -> void:
	var roll := randf()
	
	if roll < 0.35:
		current_task = TaskState.WANDERING
		var angle := randf() * TAU
		_wander_direction = Vector3(cos(angle), 0, sin(angle))
		_task_timer = randf_range(3.0, 7.0)
	elif roll < 0.70:
		current_task = TaskState.EXAMINING # Farming / Inspecting state!
		var angle := randf() * TAU
		_wander_direction = Vector3(cos(angle), 0, sin(angle))
		_task_timer = randf_range(2.0, 5.0)
	else:
		current_task = TaskState.IDLE
		_task_timer = randf_range(1.5, 4.0)

## Beautiful procedural animations (head nodding, arm swaying, walking tilts)
func _process_procedural_animations(delta: float) -> void:
	_animation_time += delta
	
	# Turn visuals towards their travel or tracking direction
	if is_instance_valid(_visual_root) and _wander_direction != Vector3.ZERO:
		var target_look := global_position + _wander_direction
		_visual_root.look_at(target_look, Vector3.UP)
		_visual_root.rotation.x = 0
		_visual_root.rotation.z = 0
		
	# 1. GREETING: Nod head up and down slightly to simulate a verbal greet
	if current_task == TaskState.GREETING:
		if is_instance_valid(_head_node):
			_head_node.rotation.x = sin(_animation_time * 6.0) * 0.15 # Nodding hello!
		if is_instance_valid(_arms_node):
			_arms_node.rotation.x = 0.0
			
	# 2. EXAMINING: Look downward and swing arms slightly to simulate working
	elif current_task == TaskState.EXAMINING:
		if is_instance_valid(_head_node):
			# Look downward at the ground
			_head_node.rotation.x = lerp(_head_node.rotation.x, deg_to_rad(25), delta * 5.0)
		if is_instance_valid(_arms_node):
			# Sway arms vertically to simulate hoeing/shoveling
			_arms_node.position.y = -0.21 + sin(_animation_time * 8.0) * 0.03
			
	# 3. WANDERING: Sway head left-to-right organically and tilt torso during movement
	elif current_task == TaskState.WANDERING:
		var speed_mult := 8.0 if (entity_type == Type.CHICKEN) else 5.0
		var sway_amount := 0.2 if (entity_type == Type.CHICKEN) else 0.08
		
		if is_instance_valid(_head_node):
			# Rhythmic head bobbing while walking
			_head_node.rotation.x = sin(_animation_time * speed_mult) * sway_amount
			_head_node.rotation.y = cos(_animation_time * (speed_mult * 0.5)) * 0.05
			
		if is_instance_valid(_arms_node):
			# Folded arms bob with the walk cycle
			_arms_node.position.y = -0.21 + sin(_animation_time * 10.0) * 0.02
			
	# 4. IDLE: Return all nodes back to baseline resting positions smoothly
	else:
		if is_instance_valid(_head_node):
			_head_node.rotation.x = lerp(_head_node.rotation.x, 0.0, delta * 5.0)
			_head_node.rotation.y = lerp(_head_node.rotation.y, 0.0, delta * 5.0)
		if is_instance_valid(_arms_node):
			_arms_node.position.y = lerp(_arms_node.position.y, -0.21, delta * 5.0)
