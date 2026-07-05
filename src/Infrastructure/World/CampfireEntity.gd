# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Static Entity representing an active, cozy Campfire.
#              Assembles a 3D log pile, mounts an organic flickering OmniLight3D, 
#              and controls CPU-bound fire/smoke particle loops.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                3D visual assembly, light flickers, and particle loops.
#              - Liskov Substitution Principle (LSP): Extends StaticBody3D cleanly 
#                to act as a physical collidable obstacle in the world.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/CampfireEntity.gd
# ==============================================================================
class_name CampfireEntity
extends StaticBody3D

# Visual Joint & Component references
var _fire_light: OmniLight3D
var _fire_particles: CPUParticles3D
var _smoke_particles: CPUParticles3D

# Internal timer for light flickering calculations
var _flicker_time: float = 0.0


func _ready() -> void:
	name = "Prop_CAMPFIRE"
	_flicker_time = randf_range(0.0, 100.0)
	
	_build_3d_log_base()
	_setup_flickering_light()
	_setup_burning_particles()
	_setup_collision()


## Programmatically assembles the cross-log base structure out of oak-wood colored boxes
func _build_3d_log_base() -> void:
	var wood_color := Color(0.45, 0.30, 0.15)      # Oak brown
	var coal_color := Color(0.12, 0.12, 0.14)      # Charred black logs
	var ash_color := Color(0.55, 0.55, 0.58)       # Gray ash floor
	
	# 1. Base Ash Floor Layer (Y+0.05)
	_create_box(self, Vector3(0.68, 0.04, 0.68), Vector3(0, 0.02, 0), ash_color)
	
	# 2. Layer 1: Two parallel oak logs pointing North-South (Z axis)
	_create_box(self, Vector3(0.14, 0.14, 0.72), Vector3(-0.22, 0.09, 0), wood_color)
	_create_box(self, Vector3(0.14, 0.14, 0.72), Vector3(0.22, 0.09, 0), wood_color)
	
	# 3. Layer 2: Two parallel oak logs pointing East-West (X axis) crossing over Layer 1
	_create_box(self, Vector3(0.72, 0.14, 0.14), Vector3(0, 0.21, -0.22), wood_color)
	_create_box(self, Vector3(0.72, 0.14, 0.14), Vector3(0, 0.21, 0.22), wood_color)
	
	# 4. Central Charred Coals (Inside the core where the fire sits)
	_create_box(self, Vector3(0.24, 0.12, 0.24), Vector3(0, 0.15, 0), coal_color)


## Configures a warm yellow-orange OmniLight3D to illuminate surrounding blocks at night
func _setup_flickering_light() -> void:
	_fire_light = OmniLight3D.new()
	_fire_light.name = "CampfireLight"
	_fire_light.light_color = Color(1.0, 0.65, 0.25) # Incandescent campfire orange
	_fire_light.light_energy = 2.5
	_fire_light.light_indirect_energy = 1.2
	_fire_light.omni_range = 14.0 # Generous warm resting radius
	
	_fire_light.shadow_enabled = true
	_fire_light.shadow_bias = 0.06
	
	# Floated slightly above the logs
	_fire_light.position = Vector3(0.0, 0.45, 0.0)
	add_child(_fire_light)


## Instantiates and configures cozy, compile-free CPU particles for flame and smoke
func _setup_burning_particles() -> void:
	var fire_color := Color(1.0, 0.45, 0.0)       # Burning orange
	var smoke_color := Color(0.45, 0.45, 0.48, 0.35) # Soft translucent grey
	
	# ==========================================================================
	# 1. FLAME CPU PARTICLES (Glowing orange embers floating up)
	# ==========================================================================
	_fire_particles = CPUParticles3D.new()
	_fire_particles.name = "FlameParticles"
	_fire_particles.amount = 14
	_fire_particles.lifetime = 0.8
	_fire_particles.explosiveness = 0.0
	_fire_particles.position = Vector3(0, 0.25, 0)
	
	_fire_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fire_particles.emission_box_extents = Vector3(0.12, 0.02, 0.12)
	_fire_particles.direction = Vector3(0, 1.0, 0)
	_fire_particles.spread = 15.0
	_fire_particles.gravity = Vector3(0, 1.2, 0) # Drift up
	_fire_particles.initial_velocity_min = 1.2
	_fire_particles.initial_velocity_max = 2.0
	_fire_particles.scale_amount_min = 0.4
	_fire_particles.scale_amount_max = 0.8
	
	# Emissive orange materials
	var fire_mesh := BoxMesh.new()
	fire_mesh.size = Vector3(0.1, 0.1, 0.1)
	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = fire_color
	fire_mat.emission_enabled = true
	fire_mat.emission = fire_color
	fire_mat.emission_energy_multiplier = 3.0 # High glow
	fire_mesh.material = fire_mat
	_fire_particles.mesh = fire_mesh
	
	add_child(_fire_particles)
	
	# ==========================================================================
	# 2. SMOKE CPU PARTICLES (Translucent grey smoke floating higher and fading)
	# ==========================================================================
	_smoke_particles = CPUParticles3D.new()
	_smoke_particles.name = "SmokeParticles"
	_smoke_particles.amount = 8
	_smoke_particles.lifetime = 2.4
	_smoke_particles.position = Vector3(0, 0.35, 0)
	
	_smoke_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_smoke_particles.emission_box_extents = Vector3(0.08, 0.02, 0.08)
	_smoke_particles.direction = Vector3(0, 1.0, 0)
	_smoke_particles.spread = 10.0
	_smoke_particles.gravity = Vector3(-0.2, 0.8, -0.1) # Slowly drift sideways with the wind
	_smoke_particles.initial_velocity_min = 0.8
	_smoke_particles.initial_velocity_max = 1.4
	_smoke_particles.scale_amount_min = 0.8
	_smoke_particles.scale_amount_max = 1.8
	
	# Transparent grey material
	var smoke_mesh := BoxMesh.new()
	smoke_mesh.size = Vector3(0.15, 0.15, 0.15)
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.albedo_color = smoke_color
	smoke_mat.roughness = 1.0
	smoke_mesh.material = smoke_mat
	_smoke_particles.mesh = smoke_mesh
	
	add_child(_smoke_particles)


func _setup_collision() -> void:
	var col_shape := CollisionShape3D.new()
	col_shape.name = "CampfireCollider"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.8, 0.35, 0.8)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0, 0.175, 0) # Resting on ground level
	add_child(col_shape)


func _create_box(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_pos
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh_instance.material_override = mat
	
	parent.add_child(mesh_instance)


func _process(delta: float) -> void:
	# Flickers light energy organically to mimic real-time burning wood
	if is_instance_valid(_fire_light):
		_flicker_time += delta * 15.0
		# Combine high-frequency and low-frequency sin waves for realistic chaotic flicker
		var noise_val := sin(_flicker_time) * 0.15 + cos(_flicker_time * 0.45) * 0.08
		_fire_light.light_energy = 2.5 + noise_val


## Dynamic Proximity interact: Triggers cozy warmth healing on player if approached
func interact(player_node: CharacterBody3D) -> void:
	if is_instance_valid(player_node):
		var entity_domain := player_node.get("domain_entity") as VoxelEntity
		if is_instance_valid(entity_domain) and entity_domain.health < 3:
			# Direct, solid OOP heal of 1 Heart if injured
			entity_domain.health = min(3, entity_domain.health + 1)
			
			var hud := player_node.get("hud") as PlayerHUD
			if is_instance_valid(hud):
				hud.update_health_display(entity_domain.health)
				hud.show_quest_notification("NOTIFICATION_CONSUME_FOOD_HEADER", "DIALOGUE_GOLEM_RUMBLE") # Triggers healing toast
				
			# Play cozy sizzling popping sound statically
			AudioService.play_sfx_static("block_break", global_position)
