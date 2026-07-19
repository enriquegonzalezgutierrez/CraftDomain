# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/ChickenEntity.gd
# Description: Physical character controller for the passive Prairie Chicken.
#              Manages high-frequency physics ticks, soil pecking animations, 
#              unshaded feather/dust particles, and slow-falling flutters.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates exclusively visual sways, 
#   sound triggers, and particle emissions, delegating state decisions to ChickenAIBehavior.
# - Dependency Inversion Principle (DIP): Uses local decoupled metadata keys 
#   to break Godot 4's cyclic preloader compile locks with its behavior script.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChickenEntity
extends PassiveEntity

## Decoupled local metadata key to prevent cyclic compile locks with ChickenAIBehavior
const META_STATE = "chicken_local_state"


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 2)
	entity_habitat = 0 
	name = "Entity_CHICKEN"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/chicken") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
		
	_setup_nameplate_height()


func _get_entity_name_key() -> String:
	return "NPC_NAME_CHICKEN"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1) # Chicken meat


func _is_avian() -> bool:
	return true


func _can_fly() -> bool:
	return true # Enables standard gravity bypass during mid-air flutters


## High-Frequency Physics Loop (Runs at 120Hz on the physics thread)
func _physics_tick(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	_process_chicken_physics(delta)


func _process_chicken_physics(delta: float) -> void:
	if not is_instance_valid(visual_component) or not is_instance_valid(visual_component.body_bob_node):
		return
		
	var body := visual_component.body_bob_node
	var time_sec := float(Time.get_ticks_msec()) / 1000.0
	
	if is_on_floor():
		set_meta("avian_flight_state", 2)
		_process_grounded_animations(body, time_sec, delta)
	else:
		set_meta("avian_flight_state", 0)
		_process_airborne_flutter_physics(body, time_sec, delta)


func _process_grounded_animations(body: Node3D, time_sec: float, delta: float) -> void:
	var state := 0 # 0 = WANDERING, 1 = PECKING
	if has_meta(META_STATE):
		state = get_meta(META_STATE) as int
		
	if state == 1: # STATE_PECKING
		body.rotation.x = lerp_angle(body.rotation.x, deg_to_rad(35.0), delta * 12.0)
		body.rotation.y = sin(time_sec * 32.0) * 0.05
		
		if Engine.get_physics_frames() % 8 == 0:
			_spawn_pecking_particles()
			AudioService.play_sfx_static("footstep_grass", global_position)
	else: # STATE_WANDERING
		body.rotation.x = lerp_angle(body.rotation.x, 0.0, delta * 6.0)
		body.rotation.y = lerp_angle(body.rotation.y, 0.0, delta * 6.0)


func _process_airborne_flutter_physics(body: Node3D, time_sec: float, delta: float) -> void:
	velocity.y = lerp(velocity.y, -1.8, delta * 3.5)
	
	body.rotation.x = sin(time_sec * 24.0) * 0.12
	body.rotation.y = cos(time_sec * 24.0) * 0.12
	
	if Engine.get_physics_frames() % 12 == 0:
		_spawn_feather_particles()
		AudioService.play_sfx_static("npc_chat", global_position)


func _spawn_pecking_particles() -> void:
	var particles := CPUParticles3D.new()
	_configure_pecking_particle_properties(particles)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.78, 0.25) 
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	
	var beak_offset := -global_transform.basis.z.normalized() * 0.2
	particles.global_position = global_position + beak_offset + Vector3(0.0, 0.02, 0.0)
	particles.emitting = true


func _configure_pecking_particle_properties(particles: CPUParticles3D) -> void:
	var beak_offset := -global_transform.basis.z.normalized() * 0.2
	particles.amount = 3
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.3
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.08
	particles.direction = Vector3.UP + beak_offset * 0.5
	particles.spread = 30.0
	particles.initial_velocity_min = 0.8
	particles.initial_velocity_max = 1.5
	particles.gravity = Vector3(0.0, -9.8, 0.0)


func _spawn_feather_particles() -> void:
	var particles := CPUParticles3D.new()
	_configure_feather_particle_properties(particles)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.02, 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.98, 0.98, 0.98, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	
	particles.global_position = global_position + Vector3(0.0, 0.25, 0.0)
	particles.emitting = true


func _configure_feather_particle_properties(particles: CPUParticles3D) -> void:
	particles.amount = 3
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.lifetime = 0.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.2
	particles.direction = Vector3.UP
	particles.spread = 45.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.0
	particles.gravity = Vector3(0.0, -2.5, 0.0)
