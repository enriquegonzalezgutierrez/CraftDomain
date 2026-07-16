# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/PigEntity.gd
# Description: Physical character controller for the passive grasslands Pig.
#              Manages high-frequency physics ticks, tilling animations, 
#              unshaded dirt particles, and auditory vocalizations.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates exclusively visual sways, 
#   sound triggers, and particle emissions, delegating state decisions to PigAIBehavior.
# - 120 FPS Guardrail: Computes procedural snout tilt translations at 120Hz inside the
#   physics thread to guarantee ultra-smooth movements.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PigEntity
extends PassiveEntity

const COOLDOWN_OINK_MIN_SEC: float = 18.0
const COOLDOWN_OINK_MAX_SEC: float = 35.0

var _oink_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 4)
	entity_habitat = 0 
	name = "Entity_PIG"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/pig") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
	
	_setup_nameplate_height()


func _get_entity_name_key() -> String:
	return "NPC_NAME_PIG"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1) # Pork meat


## High-Frequency Physics Loop (Runs at 120Hz on the physics thread)
func _physics_tick(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	_process_tilling_animations(delta)


func _process_tilling_animations(delta: float) -> void:
	if not is_instance_valid(visual_component) or not is_instance_valid(visual_component.body_bob_node):
		return
		
	var state := 0 # 0 = WANDERING, 1 = SNIFFING, 2 = TILLING
	if has_meta(PigAIBehavior.META_STATE):
		state = get_meta(PigAIBehavior.META_STATE) as int
		
	var body := visual_component.body_bob_node
	var time_sec := float(Time.get_ticks_msec()) / 1000.0
	
	match state:
		1: # STATE_SNIFFING
			# Tilt the snout down slightly and sniff/wobble left and right
			body.rotation.x = lerp_angle(body.rotation.x, deg_to_rad(15.0), delta * 6.0)
			body.rotation.y = sin(time_sec * 12.0) * 0.08
		2: # STATE_TILLING
			# Tilt the snout down heavily and vibrate frantically
			body.rotation.x = lerp_angle(body.rotation.x, deg_to_rad(25.0), delta * 8.0)
			body.rotation.y = sin(time_sec * 24.0) * 0.04
			
			# Spawn tilling dirt particles under the snout periodically
			if Engine.get_physics_frames() % 10 == 0:
				_spawn_tilling_particles()
				AudioService.play_sfx_static("footstep_grass", global_position)
		0: # STATE_WANDERING
			# Return to flat grazing level
			body.rotation.x = lerp_angle(body.rotation.x, 0.0, delta * 5.0)
			body.rotation.y = lerp_angle(body.rotation.y, 0.0, delta * 5.0)


## Triggered by PigAIBehavior upon completing a successful soil till
func _play_tilling_joy_hop() -> void:
	velocity.y = JUMP_VELOCITY
	AudioService.play_sfx_static("pig_oink", global_position)
	_spawn_joy_particles()


func _spawn_tilling_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 4
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.35
	
	# Project forward offset to spawn exactly beneath the snout
	var snout_offset := -global_transform.basis.z.normalized() * 0.4
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.1
	particles.direction = Vector3.UP + snout_offset * 0.5
	particles.spread = 25.0
	particles.initial_velocity_min = 1.2
	particles.initial_velocity_max = 2.0
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.32, 0.20) # Dirt brown
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	
	particles.global_position = global_position + snout_offset + Vector3(0.0, 0.05, 0.0)
	particles.emitting = true


func _spawn_joy_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 8
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.5
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.3
	particles.direction = Vector3.UP
	particles.spread = 45.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 3.5
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.78, 0.25) # Grass green
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	
	particles.global_position = global_position + Vector3(0.0, 0.4, 0.0)
	particles.emitting = true


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5:
		is_panicking = true
		
	if not is_panicking:
		_oink_timer -= delta
		if _oink_timer <= 0.0:
			_oink_timer = randf_range(COOLDOWN_OINK_MIN_SEC, COOLDOWN_OINK_MAX_SEC)
			AudioService.play_sfx_static("pig_oink", global_position, 40.0)
