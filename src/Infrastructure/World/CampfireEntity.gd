# ==============================================================================
# Pathfile: res://src/Infrastructure/World/CampfireEntity.gd
# Description: Infrastructure Static Entity representing an active, cozy Campfire.
#              Manages light flickering calculations and player proximity healing.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CampfireEntity
extends StaticBody3D

@onready var _fire_light: OmniLight3D = $CampfireLight

# Interactive particles (Spawned programmatically on ready to prevent file-bloat)
var _fire_particles: CPUParticles3D
var _smoke_particles: CPUParticles3D

# Internal timer for light flickering calculations
var _flicker_time: float = 0.0


func _ready() -> void:
	name = "Prop_CAMPFIRE"
	_flicker_time = randf_range(0.0, 100.0)
	
	_setup_burning_particles()


## Instantiates and configures cozy, compile-free CPU particles for flame and tall smoke
func _setup_burning_particles() -> void:
	var fire_color := Color(1.0, 0.45, 0.0)       # Burning orange
	var smoke_color := Color(0.35, 0.35, 0.38, 0.45) # Dense, visible grey smoke
	
	# 1. FLAME CPU PARTICLES (Licking up the sword blade)
	_fire_particles = CPUParticles3D.new()
	_fire_particles.name = "FlameParticles"
	_fire_particles.amount = 18
	_fire_particles.lifetime = 1.0
	_fire_particles.position = Vector3(0, 0.25, 0)
	
	_fire_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fire_particles.emission_box_extents = Vector3(0.15, 0.02, 0.15)
	_fire_particles.direction = Vector3(0, 1.0, 0)
	_fire_particles.spread = 15.0
	_fire_particles.gravity = Vector3(0, 1.8, 0)
	_fire_particles.initial_velocity_min = 1.5
	_fire_particles.initial_velocity_max = 2.5
	_fire_particles.scale_amount_min = 0.3
	_fire_particles.scale_amount_max = 0.7
	
	var fire_mesh := BoxMesh.new()
	fire_mesh.size = Vector3(0.12, 0.12, 0.12)
	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = fire_color
	fire_mat.emission_enabled = true
	fire_mat.emission = fire_color
	fire_mat.emission_energy_multiplier = 3.5
	fire_mesh.material = fire_mat
	_fire_particles.mesh = fire_mesh
	add_child(_fire_particles)
	
	# 2. BEACON SMOKE PARTICLES (Visible from afar, towering into the sky)
	_smoke_particles = CPUParticles3D.new()
	_smoke_particles.name = "SmokeParticles"
	_smoke_particles.amount = 24
	_smoke_particles.lifetime = 5.5
	_smoke_particles.position = Vector3(0, 0.6, 0)
	
	_smoke_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_smoke_particles.emission_box_extents = Vector3(0.12, 0.02, 0.12)
	_smoke_particles.direction = Vector3(0, 1.0, 0)
	_smoke_particles.spread = 8.0
	_smoke_particles.gravity = Vector3(-0.4, 2.5, -0.2)
	_smoke_particles.initial_velocity_min = 1.0
	_smoke_particles.initial_velocity_max = 1.8
	_smoke_particles.scale_amount_min = 1.0
	_smoke_particles.scale_amount_max = 4.5
	
	var smoke_mesh := BoxMesh.new()
	smoke_mesh.size = Vector3(0.2, 0.2, 0.2)
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.albedo_color = smoke_color
	smoke_mat.roughness = 1.0
	smoke_mesh.material = smoke_mat
	_smoke_particles.mesh = smoke_mesh
	add_child(_smoke_particles)


func _process(delta: float) -> void:
	if is_instance_valid(_fire_light):
		_flicker_time += delta * 15.0
		var noise_val := sin(_flicker_time) * 0.15 + cos(_flicker_time * 0.45) * 0.08
		_fire_light.light_energy = 2.8 + noise_val


## Dynamic Proximity interact: Triggers cozy warmth healing on player if approached
func interact(player_node: CharacterBody3D) -> void:
	if is_instance_valid(player_node):
		var entity_domain := player_node.get("domain_entity") as VoxelEntity
		if is_instance_valid(entity_domain) and entity_domain.health < 3:
			entity_domain.health = min(3, entity_domain.health + 1)
			
			var hud := player_node.get("hud") as PlayerHUD
			if is_instance_valid(hud):
				hud.update_health_display(entity_domain.health)
				hud.show_quest_notification(tr("NOTIFICATION_CONSUME_FOOD_HEADER"), tr("NOTIFICATION_HUMANITY_RESTORED"))
				
			AudioService.play_sfx_static("block_break", global_position)
