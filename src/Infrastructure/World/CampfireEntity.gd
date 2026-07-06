# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Static Entity representing an active, cozy Campfire.
#              Assembles a 3D log base, a rusted Greatsword thrust into the coals,
#              an organic flickering OmniLight3D, and tall beacon smoke particles.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                3D visual assembly, light flickers, and particle loops.
#              - Liskov Substitution Principle (LSP): Extends StaticBody3D cleanly 
#                to act as a physical collidable obstacle in the world.
#              - i18n Localization: Wrapped the easter-egg healing notification
#                in a dynamic `tr()` lookup.
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
	
	_build_3d_log_and_sword_base()
	_setup_flickering_light()
	_setup_burning_particles()
	_setup_collision()


## Programmatically assembles the cross-log base structure and the iconic Greatsword
func _build_3d_log_and_sword_base() -> void:
	var wood_color := Color(0.45, 0.30, 0.15)      # Oak brown
	var coal_color := Color(0.12, 0.12, 0.14)      # Charred black logs
	var ash_color := Color(0.55, 0.55, 0.58)       # Gray ash floor
	
	# Sword Colors
	var sword_metal := Color(0.25, 0.22, 0.22)     # Rusted, dark steel
	var sword_glow := Color(1.0, 0.35, 0.05)       # Red-hot glowing metal
	var sword_brass := Color(0.65, 0.45, 0.15)     # Tarnished brass/gold for the guard
	var sword_grip := Color(0.18, 0.12, 0.08)      # Dark leather wrap
	
	# 1. Base Ash Floor Layer (Y+0.05)
	_create_box(self, Vector3(0.68, 0.04, 0.68), Vector3(0, 0.02, 0), ash_color)
	
	# 2. Layer 1: Two parallel oak logs pointing North-South (Z axis)
	_create_box(self, Vector3(0.14, 0.14, 0.72), Vector3(-0.22, 0.09, 0), wood_color)
	_create_box(self, Vector3(0.14, 0.14, 0.72), Vector3(0.22, 0.09, 0), wood_color)
	
	# 3. Layer 2: Two parallel oak logs pointing East-West (X axis) crossing over Layer 1
	_create_box(self, Vector3(0.72, 0.14, 0.14), Vector3(0, 0.21, -0.22), wood_color)
	_create_box(self, Vector3(0.72, 0.14, 0.14), Vector3(0, 0.21, 0.22), wood_color)
	
	# 4. Central Charred Coals
	_create_box(self, Vector3(0.24, 0.12, 0.24), Vector3(0, 0.15, 0), coal_color)
	
	# ==========================================================================
	# 5. THE GREATSWORD (Clavada en las brasas)
	# ==========================================================================
	var sword_pivot := Node3D.new()
	sword_pivot.name = "SwordPivot"
	sword_pivot.position = Vector3(0.0, 0.15, 0.0) # Rest on the coals
	# Inclinación orgánica: Tilted back and rotated slightly
	sword_pivot.rotation = Vector3(deg_to_rad(12), deg_to_rad(35), deg_to_rad(-8))
	add_child(sword_pivot)
	
	# Base of the blade (Glowing red-hot from the fire)
	var hot_blade := _create_box(sword_pivot, Vector3(0.06, 0.35, 0.14), Vector3(0, 0.175, 0), sword_glow)
	var glow_mat := hot_blade.material_override as StandardMaterial3D
	glow_mat.emission_enabled = true
	glow_mat.emission = sword_glow
	glow_mat.emission_energy_multiplier = 2.5
	
	# Main rusted blade
	_create_box(sword_pivot, Vector3(0.04, 0.90, 0.10), Vector3(0, 0.80, 0), sword_metal)
	
	# Crossguard (Guarda de la espada)
	_create_box(sword_pivot, Vector3(0.35, 0.08, 0.12), Vector3(0, 1.29, 0), sword_brass)
	
	# Grip (Empuñadura de cuero)
	_create_box(sword_pivot, Vector3(0.05, 0.28, 0.05), Vector3(0, 1.47, 0), sword_grip)
	
	# Pommel (Pomo inferior)
	_create_box(sword_pivot, Vector3(0.10, 0.08, 0.10), Vector3(0, 1.65, 0), sword_brass)


## Configures a warm yellow-orange OmniLight3D to illuminate surrounding blocks at night
func _setup_flickering_light() -> void:
	_fire_light = OmniLight3D.new()
	_fire_light.name = "CampfireLight"
	_fire_light.light_color = Color(1.0, 0.65, 0.25) # Incandescent campfire orange
	_fire_light.light_energy = 2.8
	_fire_light.light_indirect_energy = 1.5
	_fire_light.omni_range = 18.0 # Expanded range so the glow is seen from further away
	
	_fire_light.shadow_enabled = true
	_fire_light.shadow_bias = 0.06
	
	# Floated slightly above the logs
	_fire_light.position = Vector3(0.0, 0.45, 0.0)
	add_child(_fire_light)


## Instantiates and configures cozy, compile-free CPU particles for flame and tall smoke
func _setup_burning_particles() -> void:
	var fire_color := Color(1.0, 0.45, 0.0)       # Burning orange
	var smoke_color := Color(0.35, 0.35, 0.38, 0.45) # Dense, visible grey smoke
	
	# ==========================================================================
	# 1. FLAME CPU PARTICLES (Licking up the sword blade)
	# ==========================================================================
	_fire_particles = CPUParticles3D.new()
	_fire_particles.name = "FlameParticles"
	_fire_particles.amount = 18
	_fire_particles.lifetime = 1.0
	_fire_particles.explosiveness = 0.0
	_fire_particles.position = Vector3(0, 0.25, 0)
	
	_fire_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fire_particles.emission_box_extents = Vector3(0.15, 0.02, 0.15)
	_fire_particles.direction = Vector3(0, 1.0, 0)
	_fire_particles.spread = 15.0
	_fire_particles.gravity = Vector3(0, 1.8, 0) # Faster drift up the sword
	_fire_particles.initial_velocity_min = 1.5
	_fire_particles.initial_velocity_max = 2.5
	_fire_particles.scale_amount_min = 0.3
	_fire_particles.scale_amount_max = 0.7
	
	# Emissive orange materials
	var fire_mesh := BoxMesh.new()
	fire_mesh.size = Vector3(0.12, 0.12, 0.12)
	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = fire_color
	fire_mat.emission_enabled = true
	fire_mat.emission = fire_color
	fire_mat.emission_energy_multiplier = 3.5 # Intense glow
	fire_mesh.material = fire_mat
	_fire_particles.mesh = fire_mesh
	
	add_child(_fire_particles)
	
	# ==========================================================================
	# 2. BEACON SMOKE PARTICLES (Visible from afar, towering into the sky)
	# ==========================================================================
	_smoke_particles = CPUParticles3D.new()
	_smoke_particles.name = "SmokeParticles"
	_smoke_particles.amount = 24       # More particles for a thicker plume
	_smoke_particles.lifetime = 5.5    # Lasts much longer to reach high into the sky
	_smoke_particles.position = Vector3(0, 0.6, 0)
	
	_smoke_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_smoke_particles.emission_box_extents = Vector3(0.12, 0.02, 0.12)
	_smoke_particles.direction = Vector3(0, 1.0, 0)
	_smoke_particles.spread = 8.0
	
	# Strong upward gravity acts as an updraft pillar
	_smoke_particles.gravity = Vector3(-0.4, 2.5, -0.2) 
	_smoke_particles.initial_velocity_min = 1.0
	_smoke_particles.initial_velocity_max = 1.8
	
	# Smoke expands massively as it rises
	_smoke_particles.scale_amount_min = 1.0
	_smoke_particles.scale_amount_max = 4.5 
	
	# Transparent grey material
	var smoke_mesh := BoxMesh.new()
	smoke_mesh.size = Vector3(0.2, 0.2, 0.2)
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
	# Height increased to cover the sword so players don't walk through the blade
	box_shape.size = Vector3(0.8, 1.8, 0.8) 
	col_shape.shape = box_shape
	col_shape.position = Vector3(0, 0.9, 0) 
	add_child(col_shape)


func _create_box(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> MeshInstance3D:
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
	return mesh_instance


func _process(delta: float) -> void:
	# Flickers light energy organically to mimic real-time burning wood
	if is_instance_valid(_fire_light):
		_flicker_time += delta * 15.0
		# Combine high-frequency and low-frequency sin waves for realistic chaotic flicker
		var noise_val := sin(_flicker_time) * 0.15 + cos(_flicker_time * 0.45) * 0.08
		_fire_light.light_energy = 2.8 + noise_val


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
				# Localized the easter egg string to support i18n
				hud.show_quest_notification(tr("NOTIFICATION_CONSUME_FOOD_HEADER"), tr("NOTIFICATION_HUMANITY_RESTORED"))
				
			# Play cozy sizzling popping sound statically
			AudioService.play_sfx_static("block_break", global_position)
