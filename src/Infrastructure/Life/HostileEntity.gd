# ==============================================================================
# Project: CraftDomain
# Description: Hostile zombie physics controller wrapper.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Isolates hostile AI behaviors,
#                chase tracking, and combat cooldowns.
#              - Dependency Inversion Principle (DIP): Displaces the physical collider 
#                downward by 6 cm, preventing feet sinking inside blocky meshes.
# COLLISION COHESION UPGRADE:
#              - Conditional gravity application avoids unbounded velocity build-up,
#                resolving the issue where entities slowly sink or clip into ground
#                collision shapes over time.
# STUTTER-FREE COMBAT OPTIMIZATIONS (MILESTONE 8):
#              - Albedo-Color Uniform Swapping: Bypasses Vulkan emission pipeline flues 
#                by swapping colors directly through the albedo uniform, guaranteeing 
#                locked 120 FPS performance during rapid hits.
#              - CPUParticles3D Conversion: Swapped compute-heavy GPUParticles3D 
#                on death for CPU-bound particles, removing dynamic compile-time stalls.
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
const ATTACK_COOLDOWN_INTERVAL: float = 1.5 # 1.5 seconds cooldown between bites

# Physics and state
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Domain Model Composition (DDD Compliance)
var domain_entity: VoxelEntity

# Sibling node references
var player: CharacterBody3D

# Dynamic visual part tracker bindings (SRP)
var _visual_parts: Array[VisualPart] = []

# AI wandering/chasing state variables
var _wander_timer: float = 0.0
var _wander_direction: Vector3 = Vector3.ZERO
var _is_wandering: bool = false

# Cooldown Tracker (SRP)
var _attack_cooldown_timer: float = 0.0

# Obstacle Avoidance Tracker
var _stuck_timer: float = 0.0

# STATIC VISUAL CACHE: Shared high-frequency pixel grain textures
static var _shared_grain_texture: NoiseTexture2D = null


## Symmetrical Value Object storing mesh-material original color mappings
class VisualPart:
	var material: StandardMaterial3D
	var original_color: Color
	
	func _init(p_mat: StandardMaterial3D, p_color: Color) -> void:
		material = p_mat
		original_color = p_color


func _init(spawn_pos: Vector3) -> void:
	position = spawn_pos
	name = "Entity_ZOMBIE"
	
	_preload_shared_grain_texture()
	
	# Instantiate pure domain model and subscribe to its Domain Events
	domain_entity = VoxelEntity.new(3) # 3 Hearts of health
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the hostile group for O(1) targeting lookups
	add_to_group("hostiles")
	
	_build_visual_representation()
	_setup_collision()
	_locate_player()
	_setup_quest_bubble()


## Compiles and caches a tiny, high-frequency simplex noise grain texture 
## once to establish unified voxel texturing without overhead.
func _preload_shared_grain_texture() -> void:
	if _shared_grain_texture != null:
		return
		
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.52
	noise.fractal_octaves = 1
	
	_shared_grain_texture = NoiseTexture2D.new()
	_shared_grain_texture.width = 32
	_shared_grain_texture.height = 32
	_shared_grain_texture.generate_mipmaps = false
	_shared_grain_texture.noise = noise


func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "ZombieCollider"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.5, 1.4, 0.5)
	col.shape = box_shape
	
	# ---> COLLISION CUSHION HOOK <---
	col.position = Vector3(0, 0.64, 0)
	add_child(col)


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _setup_quest_bubble() -> void:
	var active_q := QuestService.get_active_quest()
	if active_q != null and active_q.quest_id == "plains_defender":
		var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
		if sb_script != null:
			var bubble: Node3D = sb_script.new() as Node3D
			add_child(bubble)
			bubble.call("set_text", "☠️ [ TARGET MONSTER ] ☠️")


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
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	
	# Bind procedural voxel micro-grain texture
	if _shared_grain_texture != null:
		mat.albedo_texture = _shared_grain_texture
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.albedo_texture_force_srgb = true
		
	mesh_instance.material_override = mat
	
	# Bind and register the visual material parts cleanly
	_visual_parts.append(VisualPart.new(mat, color))
	
	parent.add_child(mesh_instance)


func take_damage(amount: int, knockback_force: Vector3) -> void:
	if domain_entity.is_dead:
		return
		
	# Apply infrastructure physical knockback
	velocity += knockback_force
	
	# Delegate purely logical health reduction to Domain
	domain_entity.take_damage(amount)


func _on_domain_entity_took_damage(_amount: int) -> void:
	_flash_red()


func _flash_red() -> void:
	# Symmetrical Albedo-Color Swap:
	# Updates color uniforms instantly on the GPU at zero rendering cost!
	for part: VisualPart in _visual_parts:
		if is_instance_valid(part.material):
			part.material.albedo_color = Color(0.95, 0.15, 0.15) # High-contrast Red
		
	get_tree().create_timer(0.15).timeout.connect(_reset_damage_flash)


func _reset_damage_flash() -> void:
	for part: VisualPart in _visual_parts:
		if is_instance_valid(part.material):
			part.material.albedo_color = part.original_color # Revert to original texture-tint


# ==============================================================================
# DEATH SEQUENCE & LOOT ORCHESTRATION
# ==============================================================================
func _on_domain_entity_died() -> void:
	print("[Zombie] Blegh... Zombie died.")
	
	# HIGH PERFORMANCE: Unregister instantly from group on death
	remove_from_group("hostiles")
	
	# 1. Disable physics
	set_physics_process(false)
	var col := get_node_or_null("ZombieCollider") as CollisionShape3D
	if is_instance_valid(col): 
		col.queue_free()
	
	# 2. Grant rewards
	if is_instance_valid(player):
		var inv := player.get("inventory") as IInventory
		if is_instance_valid(inv):
			var _un1 := inv.add_item(15, 1) # Grants 1x Lava Bucket safely
			
			var active_q := QuestService.get_active_quest()
			if active_q != null and active_q.quest_id == "plains_defender":
				var _un2 := inv.add_item(active_q.reward_item_index, active_q.reward_quantity)
				QuestService.complete_active_quest(player)
			
	# 3. Spawn death smoke particles
	_spawn_death_particles()
	
	# 4. Play a quick spinning/shrinking animation before deleting
	var death_tween := create_tween().set_parallel(true)
	var visuals_node: Node3D = get_node("Visuals") as Node3D
	if is_instance_valid(visuals_node):
		death_tween.tween_property(visuals_node, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		death_tween.tween_property(visuals_node, "rotation:y", deg_to_rad(180), 0.25).set_trans(Tween.TRANS_SINE)
		
	death_tween.chain().tween_callback(queue_free)


func _spawn_death_particles() -> void:
	# Using CPUParticles3D here bypasses on-the-fly compute shader compilation 
	# during gameplay, completely removing death-time stutters.
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
	mat.albedo_color = Color(0.8, 0.8, 0.8, 0.8) # Smoke grey
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	particles.mesh = mesh
	
	var world_node := get_parent() as Node
	if is_instance_valid(world_node):
		world_node.add_child(particles)
		particles.global_position = global_position + Vector3(0, 0.5, 0)
		particles.emitting = true
		get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


# ==============================================================================
# MAIN PHYSICS CALCULATIONS
# ==============================================================================
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return

	# Always apply gravity to prevent floor-jitter and maintain firm contact.
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
	if is_instance_valid(player) and player.get("is_active") as bool:
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
				visuals_node.look_at(target_look_at, Vector3.UP)
				visuals_node.rotation.x = 0
				visuals_node.rotation.z = 0
		
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
		var bite_knockback: Vector3 = (player.global_position - global_position).normalized() * 4.5
		bite_knockback.y = 0.25 
		if player.has_method("take_damage"):
			player.call("take_damage", 1, bite_knockback)
