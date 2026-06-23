# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive entity,
#              building its own geometric box visuals and executing wandering AI.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/PassiveEntity.gd
# ==============================================================================
class_name PassiveEntity
extends CharacterBody3D

## Entity Type definitions.
enum Type {
	PIG,
	CHICKEN,
	VILLAGER
}

# AI Wandering states
const SPEED: float = 1.5
const JUMP_VELOCITY: float = 5.0

# Dependencies and properties
var entity_type: Type
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# AI logic timers
var _wander_timer: float = 0.0
var _wander_direction: Vector3 = Vector3.ZERO
var _is_wandering: bool = false

func _init(p_type: Type, spawn_pos: Vector3) -> void:
	entity_type = p_type
	position = spawn_pos
	name = "Entity_%s" % Type.keys()[entity_type]

func _ready() -> void:
	_build_visual_representation()
	_setup_collision()

func _setup_collision() -> void:
	# Add standard simplified box collider matching the entity height
	var col := CollisionShape3D.new()
	col.name = "EntityCollider"
	var box_shape := BoxShape3D.new()
	
	match entity_type:
		Type.CHICKEN:
			box_shape.size = Vector3(0.4, 0.6, 0.4)
			col.position = Vector3(0, 0.3, 0)
		Type.PIG:
			box_shape.size = Vector3(0.6, 0.6, 0.8)
			col.position = Vector3(0, 0.3, 0)
		Type.VILLAGER:
			box_shape.size = Vector3(0.5, 1.4, 0.5)
			col.position = Vector3(0, 0.7, 0)
			
	col.shape = box_shape
	add_child(col)

func _build_visual_representation() -> void:
	# Root visual assembly
	var visual_root := Node3D.new()
	visual_root.name = "Visuals"
	add_child(visual_root)
	
	match entity_type:
		Type.PIG:
			_create_box(visual_root, Vector3(0.6, 0.4, 0.8), Vector3(0, 0.3, 0), Color(1.0, 0.6, 0.7)) # Torso
			_create_box(visual_root, Vector3(0.35, 0.35, 0.35), Vector3(0, 0.55, -0.45), Color(1.0, 0.55, 0.65)) # Head
			_create_box(visual_root, Vector3(0.2, 0.1, 0.1), Vector3(0, 0.45, -0.65), Color(0.9, 0.35, 0.45)) # Snout
			# Legs
			_create_box(visual_root, Vector3(0.15, 0.25, 0.15), Vector3(-0.2, 0.125, -0.25), Color(1.0, 0.6, 0.7))
			_create_box(visual_root, Vector3(0.15, 0.25, 0.15), Vector3(0.2, 0.125, -0.25), Color(1.0, 0.6, 0.7))
			_create_box(visual_root, Vector3(0.15, 0.25, 0.15), Vector3(-0.2, 0.125, 0.25), Color(1.0, 0.6, 0.7))
			_create_box(visual_root, Vector3(0.15, 0.25, 0.15), Vector3(0.2, 0.125, 0.25), Color(1.0, 0.6, 0.7))
			
		Type.CHICKEN:
			_create_box(visual_root, Vector3(0.3, 0.3, 0.4), Vector3(0, 0.3, 0), Color(0.95, 0.95, 0.95)) # Body
			_create_box(visual_root, Vector3(0.18, 0.22, 0.18), Vector3(0, 0.5, -0.2), Color(0.95, 0.95, 0.95)) # Head
			_create_box(visual_root, Vector3(0.15, 0.08, 0.12), Vector3(0, 0.5, -0.32), Color(1.0, 0.6, 0.0)) # Beak (Yellow)
			_create_box(visual_root, Vector3(0.06, 0.1, 0.06), Vector3(0, 0.4, -0.2), Color(0.9, 0.1, 0.1)) # Wattle (Red)
			# Legs (Yellow thin boxes)
			_create_box(visual_root, Vector3(0.05, 0.15, 0.05), Vector3(-0.08, 0.075, 0), Color(1.0, 0.6, 0.0))
			_create_box(visual_root, Vector3(0.05, 0.15, 0.05), Vector3(0.08, 0.075, 0), Color(1.0, 0.6, 0.0))
			
		Type.VILLAGER:
			_create_box(visual_root, Vector3(0.45, 0.9, 0.45), Vector3(0, 0.55, 0), Color(0.35, 0.22, 0.15)) # Robe (Brown)
			_create_box(visual_root, Vector3(0.3, 0.32, 0.3), Vector3(0, 1.1, 0), Color(0.95, 0.75, 0.65)) # Head (Skin)
			_create_box(visual_root, Vector3(0.08, 0.18, 0.1), Vector3(0, 1.05, -0.2), Color(0.85, 0.65, 0.55)) # Nose
			_create_box(visual_root, Vector3(0.5, 0.15, 0.2), Vector3(0, 0.65, -0.18), Color(0.25, 0.15, 0.1)) # Folded Arms

func _create_box(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_pos
	
	var mat := ORMMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh_instance.material_override = mat
	
	parent.add_child(mesh_instance)

func _physics_process(delta: float) -> void:
	# 1. Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Run simple AI state machine
	_wander_timer -= delta
	if _wander_timer <= 0:
		# Choose a new decision: rest or wander
		_is_wandering = randf() > 0.4
		if _is_wandering:
			# Pick random flat direction
			var angle := randf() * TAU
			_wander_direction = Vector3(cos(angle), 0, sin(angle))
			_wander_timer = randf_range(2.0, 5.0)
			
			# Rotate visuals towards travel direction
			var target_rot := atan2(_wander_direction.x, _wander_direction.z)
			var visuals_node: Node3D = get_node("Visuals")
			if is_instance_valid(visuals_node):
				visuals_node.rotation.y = target_rot
		else:
			_wander_direction = Vector3.ZERO
			_wander_timer = randf_range(1.0, 3.0)

	# 3. Apply wander velocity
	if _is_wandering:
		velocity.x = _wander_direction.x * SPEED
		velocity.z = _wander_direction.z * SPEED
		
		# Jump over blocks automatically if colliding with walls on floor level
		if is_on_wall() and is_on_floor():
			velocity.y = JUMP_VELOCITY
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
