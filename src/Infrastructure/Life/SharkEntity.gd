# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a hostile marine Shark.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends CharacterBody3D, 
#                matching the base collision, gravity, and lifecycle contracts.
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                to the sub-component, and physics movements to the base class.
#              - Dependency Inversion Principle (DIP): Automatically prunes 
#                extraneous Blender-exported nodes (Cameras, Lights) on initialization.
# MATHEMATICAL CALIBRATION (Baked GLB Offset Compensation):
#              - Model contains an internal baked Y-axis offset of +0.6701m in its root node.
#              - Scaled by 1.8366x to achieve a realistic predator length of ~1.8m.
#              - Grounded position Y offset set to -0.5328m to counteract the baked 
#                internal translation and anchor the lower fin to Y = 0.0.
#              - Corrected the backward orientation mesh bug by setting the 
#                Y-axis rotation offset to -90 degrees.
# 3D FLOATING NAMEPLATE INTEGRATION:
#              - Instantiates a high-contrast 3D Floating `Label3D` Nameplate above the model head.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/SharkEntity.gd
# ==============================================================================
class_name SharkEntity
extends CharacterBody3D

const MODEL_PATH := "res://assets/models/mobs/shark.glb"

# Combat configurations
const SPEED: float = 3.5
const CHASE_RANGE_SQ: float = 256.0 # 16m squared
const ATTACK_RANGE_SQ: float = 2.25 # 1.5m squared
const ATTACK_COOLDOWN_INTERVAL: float = 1.5

# Domain Model Composition (DDD)
var domain_entity: VoxelEntity
var player: CharacterBody3D

# Dynamic visual material trackers for damage flashing
var _visual_parts: Array[VisualPart] = []
var _model_node: Node3D

# AI wandering/chasing state variables
var _wander_timer: float = 0.0
var _wander_direction: Vector3 = Vector3.ZERO
var _is_wandering: bool = false
var _attack_cooldown_timer: float = 0.0
var _animation_time: float = 0.0

# UI elements
var _nameplate: Label3D


## Value Object storing mesh-material original colors for damage flash restoration
class VisualPart:
	var material: BaseMaterial3D
	var original_color: Color
	
	func _init(p_mat: BaseMaterial3D, p_color: Color) -> void:
		material = p_mat
		original_color = p_color


func _init(spawn_pos: Vector3) -> void:
	position = spawn_pos
	name = "Entity_SHARK"
	
	domain_entity = VoxelEntity.new(4) # Sharks have 4 Hearts of health
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)


func _ready() -> void:
	add_to_group("hostiles")
	
	_build_visual_representation()
	_setup_collision()
	_locate_player()
	
	_setup_nameplate()


func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "SharkCollider"
	var box_shape := BoxShape3D.new()
	
	# Calibrated to the scaled bounding box of the GLB model
	box_shape.size = Vector3(0.85, 1.80, 1.10) 
	col.shape = box_shape
	col.position = Vector3(0, 0.9, 0)
	add_child(col)


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


## Instantiates a native, high-performance Label3D billboard to display creature name
func _setup_nameplate() -> void:
	_nameplate = Label3D.new()
	_nameplate.name = "FloatingNameplate"
	_nameplate.text = tr("NPC_NAME_SHARK").to_upper()
	_nameplate.pixel_size = 0.005 # Crisp, matching speech bubble sizing scale
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.no_depth_test = false # Occluded by solid blocks
	_nameplate.render_priority = 5
	
	# Text styling and high-contrast outline
	_nameplate.modulate = Color(1.0, 1.0, 1.0)
	_nameplate.outline_modulate = Color(0, 0, 0)
	_nameplate.outline_size = 5
	
	# Set position right above the model head (1.80m height + 15cm offset = 1.95m)
	_nameplate.position = Vector3(0.0, 1.95, 0.0)
	add_child(_nameplate)


## Loads the external GLB model and applies calculated mathematical transforms
func _build_visual_representation() -> void:
	var visual_root := Node3D.new()
	visual_root.name = "Visuals"
	add_child(visual_root)
	
	if ResourceLoader.exists(MODEL_PATH):
		var model_scene := load(MODEL_PATH) as PackedScene
		_model_node = model_scene.instantiate() as Node3D
		
		_prune_extraneous_nodes(_model_node)
		
		# ======================================================================
		# MATHEMATICAL CALIBRATION (Baked GLB Compensation)
		# ======================================================================
		# 1. Scale model by 1.8366x to achieve a realistic great white length of ~1.8m
		_model_node.scale = Vector3(1.8366, 1.8366, 1.8366) 
		
		# 2. Origin offset calculation. Ground the shark by subtracting 0.5328m on Y
		_model_node.position = Vector3(0.0, -0.5328, 0.0) 
		
		# 3. Apply -90-degree visual offset to face forward (-Z)
		_model_node.rotation_degrees = Vector3(0, -90, 0) 
		# ======================================================================
		
		visual_root.add_child(_model_node)
		_register_glb_materials(_model_node)
	else:
		push_error("[SharkEntity] GLB model not found at path: " + MODEL_PATH)


## Recursively scans the GLB hierarchy to extract and duplicate mesh materials
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: Material = node.get_active_material(0) as Material
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0) as Material
			
		if mat is BaseMaterial3D:
			# Duplicate material so the red flash doesn't affect other instances
			var new_mat := mat.duplicate() as BaseMaterial3D
			
			# TANGENT WARNING SHIELD
			new_mat.normal_enabled = false
			new_mat.anisotropy_enabled = false
			new_mat.clearcoat_enabled = false
			new_mat.heightmap_enabled = false
			
			node.material_override = new_mat
			var original_color: Color = new_mat.albedo_color
			_visual_parts.append(VisualPart.new(new_mat, original_color))
			
	for child: Node in node.get_children():
		_register_glb_materials(child)


## Recursively locates and frees extraneous camera and light nodes
func _prune_extraneous_nodes(node: Node) -> void:
	for i in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		if "Camera" in child.name or "Light" in child.name:
			child.free()
		else:
			_prune_extraneous_nodes(child)


func _on_domain_entity_took_damage(_amount: int) -> void:
	_flash_red()


func _flash_red() -> void:
	for part: VisualPart in _visual_parts:
		if is_instance_valid(part.material):
			part.material.albedo_color = Color(0.95, 0.15, 0.15) 
		
	get_tree().create_timer(0.15).timeout.connect(_reset_damage_flash)


func _reset_damage_flash() -> void:
	for part: VisualPart in _visual_parts:
		if is_instance_valid(part.material):
			part.material.albedo_color = part.original_color


# ==============================================================================
# DEATH SEQUENCE & LOOT ORCHESTRATION
# ==============================================================================
func _on_domain_entity_died() -> void:
	remove_from_group("hostiles")
	set_physics_process(false)
	set_process(false) 
	
	var col := get_node_or_null("SharkCollider") as CollisionShape3D
	if is_instance_valid(col): 
		col.queue_free()
	
	if is_instance_valid(_nameplate):
		_nameplate.queue_free()
			
	_spawn_death_particles()
	
	var death_tween := create_tween().set_parallel(true)
	var visuals_node: Node3D = get_node("Visuals") as Node3D
	if is_instance_valid(visuals_node):
		death_tween.tween_property(visuals_node, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		death_tween.tween_property(visuals_node, "rotation:y", deg_to_rad(180), 0.25).set_trans(Tween.TRANS_SINE)
		
	death_tween.chain().tween_callback(queue_free)


func _spawn_death_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.amount = 15
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.6
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.4
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0, 2.0, 0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.2
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.8, 0.8, 0.8) 
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	particles.mesh = mesh
	
	var world_node := get_parent() as Node
	if is_instance_valid(world_node):
		world_node.add_child(particles)
		particles.global_position = global_position + Vector3(0, 0.9, 0)
		particles.emitting = true
		get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


# ==============================================================================
# PROCEDURAL SWIMMING ENGINE (Sinusoidal Tail-Wagging)
# ==============================================================================
func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	if is_instance_valid(_model_node):
		_animation_time += delta
		
		var flat_velocity := Vector2(velocity.x, velocity.z)
		var is_moving := flat_velocity.length_squared() > 0.1
		
		if is_moving:
			# Fast tail wagging when swimming rapidly (Yaw oscillation on Z-axis offset)
			var swim_speed := flat_velocity.length() * 2.5
			_model_node.rotation.y = deg_to_rad(-90.0) + sin(_animation_time * swim_speed) * 0.22
			_model_node.rotation.z = cos(_animation_time * swim_speed * 0.5) * 0.08 
		else:
			# Calm, idle ocean current swaying
			_model_node.rotation.y = lerp(_model_node.rotation.y, deg_to_rad(-90.0), delta * 5.0)
			_model_node.rotation.z = sin(_animation_time * 1.5) * 0.03


# ==============================================================================
# MAIN PHYSICS & SWIMMING AI CALCULATIONS
# ==============================================================================
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return

	# No gravity applied: sharks swim neutrally in the water column
	velocity.y = move_toward(velocity.y, 0, SPEED * delta)

	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	if not is_instance_valid(player):
		_locate_player()

	_process_ai_intelligence(delta)
	move_and_slide()


func _process_ai_intelligence(delta: float) -> void:
	var _wander_direction_tmp: Vector3 = Vector3.ZERO
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
			
	var is_player_trackable: bool = false
	if is_instance_valid(player) and bool(player.get("is_active")):
		var dist_sq := global_position.distance_squared_to(player.global_position)
		if dist_sq < CHASE_RANGE_SQ:
			_is_wandering = true
			_wander_direction = (player.global_position - global_position).normalized()
			_wander_direction.y = 0
			is_player_trackable = true
			
			if dist_sq <= ATTACK_RANGE_SQ:
				if _attack_cooldown_timer <= 0.0:
					_bite_player()
					_attack_cooldown_timer = ATTACK_COOLDOWN_INTERVAL
				
	if not is_player_trackable and _wander_direction_tmp != Vector3.ZERO:
		_wander_direction = _wander_direction_tmp

	if _is_wandering:
		var speed_mult: float = SPEED if is_player_trackable else (SPEED * 0.5)
		velocity.x = _wander_direction.x * speed_mult
		velocity.z = _wander_direction.z * speed_mult
		
		var visuals_node: Node3D = get_node("Visuals") as Node3D
		if is_instance_valid(visuals_node) and _wander_direction.length_squared() > 0.01:
			var target_look_at: Vector3 = global_position + _wander_direction
			if not global_position.is_equal_approx(target_look_at):
				var current_rot_x := visuals_node.rotation.x
				var current_rot_z := visuals_node.rotation.z
				visuals_node.look_at(target_look_at, Vector3.UP)
				visuals_node.rotation.x = current_rot_x
				visuals_node.rotation.z = current_rot_z
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)


func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(dir.x * 5.5, 0.25, dir.z * 5.5)
		if player.has_method("take_damage"):
			player.call("take_damage", 1, knockback)


## Drops 1x Sand Block on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 7: Sand Block
	inv.add_item(7, 1)
