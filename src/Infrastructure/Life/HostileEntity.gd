# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a hostile zombie.
#              Acts as an Infrastructure Wrapper that uses Composition to hold
#              a pure Domain VoxelEntity, reacting to Domain Events (Signals).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/HostileEntity.gd
# ==============================================================================
class_name HostileEntity
extends CharacterBody3D

# Combat configurations
const SPEED: float = 2.2
const JUMP_VELOCITY: float = 5.0
const CHASE_RANGE: float = 16.0
const ATTACK_RANGE: float = 1.2

# Physics and state
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Domain Model Composition (DDD)
var domain_entity: VoxelEntity

# Sibling node references (loosely typed to prevent compile loops)
var player: CharacterBody3D
var _visual_materials: Array[ORMMaterial3D] = []

# AI wandering/chasing state variables
var _wander_timer: float = 0.0
var _wander_direction: Vector3 = Vector3.ZERO
var _is_chasing: bool = false
var _is_wandering: bool = false

func _init(spawn_pos: Vector3) -> void:
	position = spawn_pos
	name = "Entity_ZOMBIE"
	
	# Instantiate pure domain model and subscribe to its Domain Events
	domain_entity = VoxelEntity.new(3)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)

func _ready() -> void:
	_build_visual_representation()
	_setup_collision()
	_locate_player()

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "ZombieCollider"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.5, 1.4, 0.5)
	col.shape = box_shape
	col.position = Vector3(0, 0.7, 0)
	add_child(col)

func _locate_player() -> void:
	# Clean dynamic search of sibling nodes
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		player = parent_node.get_node_or_null("Player") as CharacterBody3D

func _build_visual_representation() -> void:
	var visual_root := Node3D.new()
	visual_root.name = "Visuals"
	add_child(visual_root)
	
	# Create Zombie Box Composition (Rotated forward along -Z)
	_create_box(visual_root, Vector3(0.45, 0.9, 0.45), Vector3(0, 0.55, 0), Color(0.15, 0.35, 0.15)) # Torso
	_create_box(visual_root, Vector3(0.3, 0.32, 0.3), Vector3(0, 1.1, 0), Color(0.25, 0.6, 0.25)) # Head
	_create_box(visual_root, Vector3(0.12, 0.12, 0.5), Vector3(-0.15, 0.75, -0.28), Color(0.25, 0.6, 0.25)) # Left arm
	_create_box(visual_root, Vector3(0.12, 0.12, 0.5), Vector3(0.15, 0.75, -0.28), Color(0.25, 0.6, 0.25)) # Right arm
	# Legs
	_create_box(visual_root, Vector3(0.15, 0.45, 0.15), Vector3(-0.1, 0.225, 0), Color(0.1, 0.1, 0.25)) # Blue trousers
	_create_box(visual_root, Vector3(0.15, 0.45, 0.15), Vector3(0.1, 0.225, 0), Color(0.1, 0.1, 0.25))

func _create_box(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_pos
	
	var mat := ORMMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh_instance.material_override = mat
	_visual_materials.append(mat)
	
	parent.add_child(mesh_instance)

## Infrastructure Method: Receives combat interaction, applies physics, and delegates logic to Domain.
func take_damage(amount: int, knockback_force: Vector3) -> void:
	if domain_entity.is_dead:
		return
		
	# 1. Apply infrastructure physical knockback
	velocity += knockback_force
	
	# 2. Delegate purely logical health reduction to Domain
	domain_entity.take_damage(amount)

## Infrastructure Event Handler: Reacts to the Domain Event
func _on_domain_entity_took_damage(_amount: int) -> void:
	print("[Zombie] Groaan! Took damage! Health remaining: ", domain_entity.health)
	_flash_red()

func _flash_red() -> void:
	for mat in _visual_materials:
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.0, 0.0) # Red glow
		
	# Create a quick 0.15-second timer to restore original colors
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		for mat in _visual_materials:
			mat.emission_enabled = false
	)

## Infrastructure Event Handler: Reacts to the Domain Event
func _on_domain_entity_died() -> void:
	print("[Zombie] Blegh... Zombie died.")
	
	# Play a quick spinning/falling animation before deleting
	var death_tween := create_tween().set_parallel(true)
	var visuals_node: Node3D = get_node("Visuals")
	if is_instance_valid(visuals_node):
		death_tween.tween_property(visuals_node, "rotation:z", deg_to_rad(-90), 0.2)
		death_tween.tween_property(visuals_node, "position:y", -0.4, 0.2)
		
	death_tween.chain().tween_callback(func() -> void:
		queue_free()
	)

func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Dynamic target search fallback if player spawned late
	if not is_instance_valid(player):
		_locate_player()

	_process_ai_intelligence(delta)
	move_and_slide()

func _process_ai_intelligence(delta: float) -> void:
	var _wander_direction_tmp: Vector3 = Vector3.ZERO
	# 1. Run simple AI state machine
	_wander_timer -= delta
	if _wander_timer <= 0:
		_is_wandering = randf() > 0.4
		if _is_wandering:
			var angle := randf() * TAU
			_wander_direction_tmp = Vector3(cos(angle), 0, sin(angle))
			_wander_timer = randf_range(2.0, 5.0)
		else:
			_wander_direction_tmp = Vector3.ZERO
			_wander_timer = randf_range(1.0, 3.0)
			
	# If player is active, close by, and can be tracked, chase them! (Zombie Aggro)
	var is_player_trackable: bool = false
	if is_instance_valid(player):
		var p_active = player.get("is_active")
		if p_active and global_position.distance_to(player.global_position) < CHASE_RANGE:
			_is_wandering = true
			_wander_direction = (player.global_position - global_position).normalized()
			_wander_direction.y = 0
			is_player_trackable = true
			
			# Deal melee bites inside range
			if global_position.distance_to(player.global_position) <= ATTACK_RANGE:
				_bite_player()
				
	if not is_player_trackable and _wander_direction_tmp != Vector3.ZERO:
		_wander_direction = _wander_direction_tmp

	# 2. Apply velocities
	if _is_wandering:
		var speed_mult: float = SPEED if is_player_trackable else (SPEED * 0.5)
		velocity.x = _wander_direction.x * speed_mult
		velocity.z = _wander_direction.z * speed_mult
		
		# Turn visuals towards wander/chase direction
		var visuals_node: Node3D = get_node("Visuals")
		if is_instance_valid(visuals_node) and _wander_direction != Vector3.ZERO:
			var target_look_at: Vector3 = global_position + _wander_direction
			visuals_node.look_at(target_look_at, Vector3.UP)
			visuals_node.rotation.x = 0
			visuals_node.rotation.z = 0
		
		# Jump over blocks automatically if colliding with walls on floor level
		if is_on_wall() and is_on_floor():
			velocity.y = JUMP_VELOCITY
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

func _bite_player() -> void:
	if is_instance_valid(player):
		# Calculate knockback vector pointing directly away from the zombie
		var bite_knockback: Vector3 = (player.global_position - global_position).normalized() * 4.5
		bite_knockback.y = 2.0 # Throw the player upward slightly
		
		if player.has_method("take_damage"):
			player.call("take_damage", 1, bite_knockback)
