# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a hostile Goblin.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Isolates hostile AI behaviors,
#                chase tracking, and combat cooldowns.
#              - Liskov Substitution Principle (LSP): Extends CharacterBody3D cleanly 
#                and satisfies base physics and signal contracts.
#              - Dependency Inversion Principle (DIP): Resolves time-of-day queries 
#                statically through the decoupled CelestialService provider.
# MATHEMATICAL CALIBRATION (V5 Telemetry):
#              - Total model height is 1.00m. Scaled by 1.2x to achieve a 
#                realistic sneaky, hunched-over height of ~1.20m.
#              - Model origin is centered. Raised the model Y-position by +0.599m 
#                to anchor its feet flat on the physical voxel colliders.
#              - Corrected the sideways orientation mesh bug by setting the 
#                Y-axis rotation offset to -90 degrees.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GoblinEntity.gd
# ==============================================================================
class_name GoblinEntity
extends CharacterBody3D

const MODEL_PATH := "res://assets/models/mobs/goblin.glb"

# Combat configurations (Fast, fragile skirmisher)
const SPEED: float = 3.5
const JUMP_VELOCITY: float = 5.0
const CHASE_RANGE: float = 16.0
const ATTACK_RANGE: float = 1.2
const ATTACK_COOLDOWN_INTERVAL: float = 1.2 # Faster bite cooldown than Zombie

# Physics gravity
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Domain Model Composition (DDD Compliance)
var domain_entity: VoxelEntity

# Sibling node references
var player: CharacterBody3D

# Dynamic visual part tracker bindings (SRP)
var _visual_parts: Array[VisualPart] = []
var _model_node: Node3D

# AI wandering/chasing state variables
var _wander_timer: float = 0.0
var _wander_direction: Vector3 = Vector3.ZERO
var _is_wandering: bool = false
var _attack_cooldown_timer: float = 0.0
var _stuck_timer: float = 0.0

# Procedural Animation tracker
var _animation_time: float = 0.0


## Value Object storing mesh-material original colors for damage flash restoration
class VisualPart:
	var material: BaseMaterial3D
	var original_color: Color
	
	func _init(p_mat: BaseMaterial3D, p_color: Color) -> void:
		material = p_mat
		original_color = p_color


func _init(spawn_pos: Vector3) -> void:
	position = spawn_pos
	name = "Entity_GOBLIN"
	
	domain_entity = VoxelEntity.new(2) # Goblins have 2 Hearts of health (4 HP, fragile)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)


func _ready() -> void:
	add_to_group("hostiles")
	
	_build_visual_representation()
	_setup_collision()
	_locate_player()


func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "GoblinCollider"
	var box_shape := BoxShape3D.new()
	
	# Calibrated to the scaled bounding box of the GLB model (1.2m height)
	box_shape.size = Vector3(0.6, 1.2, 0.6)
	col.shape = box_shape
	
	# Set collider center Y position to 0.6m to align with the ground plane
	col.position = Vector3(0, 0.6, 0)
	add_child(col)


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


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
		# MATHEMATICAL CALIBRATION (Based on GLB Analyzer V5)
		# ======================================================================
		# 1. Scale model by 1.2x to achieve a realistic hunched-over height of ~1.2m
		_model_node.scale = Vector3(1.2, 1.2, 1.2) 
		
		# 2. Origin is centered. Pull it down by -0.599m on Y
		#    to anchor the feet perfectly flat on the ground plane
		_model_node.position = Vector3(0.0, -0.599, 0.0) 
		
		# 3. Apply -90-degree visual offset to correct the sideways orientation bug
		_model_node.rotation_degrees = Vector3(0, -90, 0) 
		# ======================================================================
		
		visual_root.add_child(_model_node)
		_register_glb_materials(_model_node)
	else:
		push_error("[GoblinEntity] GLB model not found at path: " + MODEL_PATH)


## Recursively scans the GLB hierarchy to extract and duplicate mesh materials
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: Material = node.get_active_material(0) as Material
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0) as Material
			
		if mat is BaseMaterial3D:
			var new_mat := mat.duplicate() as BaseMaterial3D
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


func take_damage(amount: int, knockback_force: Vector3) -> void:
	if domain_entity.is_dead:
		return
	velocity += knockback_force
	domain_entity.take_damage(amount)


func _on_domain_entity_took_damage(_amount: int) -> void:
	_flash_red()


func _flash_red() -> void:
	for part: VisualPart in _visual_parts:
		if is_instance_valid(part.material):
			part.material.albedo_color = Color(0.95, 0.15, 0.15) # Glowing Red
		
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
	set_process(false) # Disable visual procedural processing loop on death
	
	var col := get_node_or_null("GoblinCollider") as CollisionShape3D
	if is_instance_valid(col): 
		col.queue_free()
			
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
	mesh.size = Vector3(0.12, 0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.35, 0.12) # Muddy green goblin debris
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	particles.mesh = mesh
	
	var world_node := get_parent() as Node
	if is_instance_valid(world_node):
		world_node.add_child(particles)
		particles.global_position = global_position + Vector3(0, 0.6, 0)
		particles.emitting = true
		get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


# ==============================================================================
# PROCEDURAL ANIMATION (For static models without skeletal bones)
# ==============================================================================
func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var visuals_node: Node3D = get_node_or_null("Visuals") as Node3D
	if not is_instance_valid(visuals_node):
		return
		
	_animation_time += delta
	var flat_velocity := Vector2(velocity.x, velocity.z)
	
	if flat_velocity.length() > 0.1 and is_on_floor():
		# Sneaky, high-frequency lurching trot
		var bob_mult := 16.0
		visuals_node.rotation.z = sin(_animation_time * bob_mult) * 0.12
		visuals_node.rotation.x = abs(sin(_animation_time * bob_mult * 0.5)) * 0.15
	else:
		# Idle breathing sways when standing still
		visuals_node.rotation.z = lerp(visuals_node.rotation.z, 0.0, delta * 5.0)
		visuals_node.rotation.x = lerp(visuals_node.rotation.x, sin(_animation_time * 2.0) * 0.02, delta * 5.0)


# ==============================================================================
# MAIN PHYSICS & SWIMMING AI CALCULATIONS
# ==============================================================================
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

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
		if global_position.distance_to(player.global_position) < CHASE_RANGE:
			_is_wandering = true
			_wander_direction = (player.global_position - global_position).normalized()
			_wander_direction.y = 0
			is_player_trackable = true
			
			if global_position.distance_to(player.global_position) <= ATTACK_RANGE:
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
		
		if is_on_wall():
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
				
			_stuck_timer += delta
			var patience := 1.0 if is_player_trackable else 0.4 
			
			if _stuck_timer > patience:
				_stuck_timer = 0.0
				if not is_player_trackable:
					var wall_normal := get_wall_normal()
					var flat_normal := Vector3(wall_normal.x, 0, wall_normal.z).normalized()
					if flat_normal != Vector3.ZERO:
						_wander_direction = _wander_direction.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.3, 0.3)).normalized()
					else:
						var angle := randf() * TAU
						_wander_direction = Vector3(cos(angle), 0, sin(angle))
		else:
			_stuck_timer = 0.0
			
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)


func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(dir.x * 4.5, 0.25, dir.z * 4.5)
		if player.has_method("take_damage"):
			player.call("take_damage", 1, knockback)


## Drops 1x Stone Block and 1x Oak Planks on death (Reclaimed gold coin loot)
func _drop_loot(inv: IInventory) -> void:
	# Item ID 1: Stone, Item ID 29: Oak Planks
	inv.add_item(1, 1)
	inv.add_item(29, 1)
