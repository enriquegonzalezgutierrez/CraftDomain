# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive entity.
#              OCP COMPLIANT: Acts as an Abstract Base Class. Handles physical
#              instantiation of collision nodes internally, letting subclasses
#              only define their dimensions polimorphically.
#              REVERTED: Restored the original high-performance, solid-color 
#              3D box factory to return to the classic Minecraft voxel art style.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/PassiveEntity.gd
# ==============================================================================
class_name PassiveEntity
extends CharacterBody3D

## Behavioral Task States
enum TaskState {
	IDLE,       # Resting in place
	WANDERING,  # Walking randomly
	EXAMINING,  # Performing a farming/inspecting work loop on a block
	GREETING    # Stopping to look at and nod to the nearby player
}

# Base physics movement constants
const BASE_SPEED: float = 1.3
const JUMP_VELOCITY: float = 5.0

# Dependencies
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Domain Model Composition (DDD)
var domain_entity: VoxelEntity

# Behavior State Machine properties
var current_task: TaskState = TaskState.IDLE
var _task_timer: float = 2.0
var _wander_direction: Vector3 = Vector3.ZERO
var _animation_time: float = 0.0

# Dynamic Node references for subclass procedural animations
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

func _init(spawn_pos: Vector3, initial_health: int = 1) -> void:
	position = spawn_pos
	
	# Instantiate pure domain model
	domain_entity = VoxelEntity.new(initial_health)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)

func _ready() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "Visuals"
	add_child(_visual_root)
	
	# Abstract template methods: Executed by subclasses polimorphically
	_build_visual_representation()
	_setup_floating_bubble()
	
	# Instantiate and register the CollisionShape3D internally in base class!
	var col := CollisionShape3D.new()
	col.name = "EntityCollider"
	var box_shape := BoxShape3D.new()
	box_shape.size = _get_collision_box_size()
	col.shape = box_shape
	col.position = _get_collision_box_position()
	add_child(col)

## Abstract Contract: Subclasses must override this to assemble their 3D voxel models
func _build_visual_representation() -> void:
	assert(false, "[PassiveEntity] _build_visual_representation() must be implemented by subclass.")

## Abstract Contract: Subclasses must override this to declare their physical box size
func _get_collision_box_size() -> Vector3:
	assert(false, "[PassiveEntity] _get_collision_box_size() must be implemented by subclass.")
	return Vector3(1.0, 1.0, 1.0)

## Abstract Contract: Subclasses must override this to declare their physical box center offset
func _get_collision_box_position() -> Vector3:
	assert(false, "[PassiveEntity] _get_collision_box_position() must be implemented by subclass.")
	return Vector3(0.0, 0.5, 0.0)

## Virtual Contract: Subclasses can override this to attach floating speech bubbles
func _setup_floating_bubble() -> void:
	pass

## Virtual Contract: Subclasses can override this to implement custom dialogue triggers
func interact(_player: CharacterBody3D) -> void:
	pass

## Helper factory to construct 3D boxes programmatically
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
	_try_drop_player_loot()
	queue_free()

## Scans the parent node to find the Player and safely inject loot rewards
func _try_drop_player_loot() -> void:
	var parent := get_parent()
	if is_instance_valid(parent):
		var player_node := parent.get_node_or_null("Player") as CharacterBody3D
		if is_instance_valid(player_node):
			var inv: IInventory = player_node.get("inventory")
			if is_instance_valid(inv):
				_drop_loot(inv)
				player_node.call("_sync_hud_counters") # Sync HUD UI instantly

## Virtual Method: Overridden by specific subclasses to declare their unique drops
func _drop_loot(_inv: IInventory) -> void:
	pass

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

## Advanced behavior states: WANDERING, GREETING players, or EXAMINING
func _process_ai_state_machine(delta: float) -> void:
	var player_node: CharacterBody3D = get_parent().get_node_or_null("Player") as CharacterBody3D
	var distance_to_player: float = 999.0
	
	if is_instance_valid(player_node):
		distance_to_player = global_position.distance_to(player_node.global_position)
		
	var can_socialize := _can_socialize()
	
	if can_socialize and distance_to_player <= GREET_DISTANCE:
		current_task = TaskState.GREETING
		var look_dir := (player_node.global_position - global_position).normalized()
		look_dir.y = 0
		if look_dir != Vector3.ZERO:
			_wander_direction = look_dir
	else:
		_task_timer -= delta
		if _task_timer <= 0.0:
			_select_next_random_task()

	# Execute active state velocities
	match current_task:
		TaskState.IDLE, TaskState.GREETING:
			velocity.x = move_toward(velocity.x, 0, BASE_SPEED)
			velocity.z = move_toward(velocity.z, 0, BASE_SPEED)
			
		TaskState.EXAMINING:
			velocity.x = _wander_direction.x * (BASE_SPEED * 0.25)
			velocity.z = _wander_direction.z * (BASE_SPEED * 0.25)
			
		TaskState.WANDERING:
			velocity.x = _wander_direction.x * BASE_SPEED
			velocity.z = _wander_direction.z * BASE_SPEED
			
			if is_on_wall() and is_on_floor():
				velocity.y = JUMP_VELOCITY

## Virtual check: overridden by human-roles to allow social greetings
func _can_socialize() -> bool:
	return false

## Dynamically changes states to break robotic uniformity
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

## Beautiful procedural animations
func _process_procedural_animations(delta: float) -> void:
	_animation_time += delta
	
	if is_instance_valid(_visual_root) and _wander_direction != Vector3.ZERO:
		var target_look := global_position + _wander_direction
		_visual_root.look_at(target_look, Vector3.UP)
		_visual_root.rotation.x = 0
		_visual_root.rotation.z = 0
		
	if current_task == TaskState.GREETING:
		if is_instance_valid(_head_node):
			_head_node.rotation.x = sin(_animation_time * 6.0) * 0.15 
		if is_instance_valid(_arms_node):
			_arms_node.rotation.x = 0.0
			
	elif current_task == TaskState.EXAMINING:
		if is_instance_valid(_head_node):
			_head_node.rotation.x = lerp(_head_node.rotation.x, deg_to_rad(25), delta * 5.0)
		if is_instance_valid(_arms_node):
			_arms_node.position.y = -0.21 + sin(_animation_time * 8.0) * 0.03
			
	elif current_task == TaskState.WANDERING:
		var speed_mult := 8.0 if _is_avian() else 5.0
		var sway_amount := 0.2 if _is_avian() else 0.08
		
		if is_instance_valid(_head_node):
			_head_node.rotation.x = sin(_animation_time * speed_mult) * sway_amount
			_head_node.rotation.y = cos(_animation_time * (speed_mult * 0.5)) * 0.05
			
		if is_instance_valid(_arms_node):
			_arms_node.position.y = -0.21 + sin(_animation_time * 10.0) * 0.02
			
	else:
		if is_instance_valid(_head_node):
			_head_node.rotation.x = lerp(_head_node.rotation.x, 0.0, delta * 5.0)
			_head_node.rotation.y = lerp(_head_node.rotation.y, 0.0, delta * 5.0)
		if is_instance_valid(_arms_node):
			_arms_node.position.y = lerp(_arms_node.position.y, -0.21, delta * 5.0)

## Virtual check: overridden by birds (Chickens) to speed up head bobbing animations
func _is_avian() -> bool:
	return false
