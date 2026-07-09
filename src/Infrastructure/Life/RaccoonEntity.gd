# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: RaccoonEntity
# Description: Physical character controller for the forest Raccoon.
#              It delegates all daytime sleeps, nighttime village barrel stalking,
#              and scratches timers to the decoupled RaccoonAIBehavior strategy,
#              managing wood-chip particle feedback and scratch audio cues.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, and claw scratch visual wood particles.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, relying 100% on the base physics loop for standard translations.
# - Dependency Inversion Principle (DIP): Injects the RaccoonAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/RaccoonEntity.gd
# ==============================================================================
class_name RaccoonEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Raccoons spawn with 2 Hearts of health (4 HP)
	super(spawn_pos, 4)
	name = "Entity_RACCOON"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Raccoon cleptomaniac AI strategy dynamically on ready,
	# completely overriding the default generic wildlife behavior assigned by Bootstrap.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = RaccoonAIBehavior.new()


## Decoupled height calculation sourcing boundaries directly from the scene setup
func _setup_nameplate_height() -> void:
	var col := get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col) and col.shape is CylinderShape3D:
		var cylinder := col.shape as CylinderShape3D
		_collision_height = cylinder.height
		
	_setup_nameplate()
	
	if is_instance_valid(_nameplate):
		_nameplate.position.y = _collision_height + 0.35


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

## Returns int directly (0 = TERRESTRIAL, 1 = AMPHIBIOUS, 2 = AQUATIC)
func _get_habitat() -> int:
	return 0 # Equivalent to MobRegistry.Habitat.TERRESTRIAL


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Fried Chicken (acting as soft feline meat proxy)
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


# ==============================================================================
# TACTICAL CLAW SCRATCHING & BARREL BREAKOUT EFFECTS
# ==============================================================================

## Visual Scratching: Directs gaze towards targeted barrel, triggers scratch sound and wood chips
## Note: Invoked via reflective calls by the RaccoonAIBehavior strategy
func _play_scratching_effect(target_node: Node3D) -> void:
	if not is_instance_valid(target_node):
		return
		
	# Gaze lock towards the target
	var look_dir := (target_node.global_position - global_position).normalized()
	look_dir.y = 0.0
	if is_instance_valid(ai_component):
		ai_component.wander_direction = look_dir
		
	# Gesticulate scratch swipes and throttle wood chip spawn rate
	var frame_stamp := Engine.get_physics_frames()
	if frame_stamp % 10 == 0:
		_spawn_claw_wood_particles(target_node.global_position)
		
		# Play claw scratch sound statically (Service Locator)
		AudioService.play_sfx_static("footstep_wood", global_position)


## Spawns tiny unshaded wood shavings that drift down via gravity (Compile-Free CPU)
func _spawn_claw_wood_particles(target_pos: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 4
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.40
	
	# Flying direction: wood shavings bounce back towards the Raccoon
	var direction_vec := (global_position - target_pos).normalized()
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.1
	particles.direction = direction_vec
	particles.spread = 30.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 2.5
	particles.gravity = Vector3(0.0, -9.8, 0.0) # Wood chips fall under gravity
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.03, 0.03) # Tiny wood shavings
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.30, 0.15) # Wood Oak Brown
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	
	# Add to world parent node to prevent particles moving with the raccoon
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(particles)
		
		# Symmetrical start pos: spawn right in between raccoon and targeted prop
		particles.global_position = global_position.lerp(target_pos, 0.6) + Vector3(0.0, 0.2, 0.0)
		particles.emitting = true
		
		# Safe memory cleanup direct connection
		get_tree().create_timer(0.45).timeout.connect(particles.queue_free)
