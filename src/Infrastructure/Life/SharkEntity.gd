# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/SharkEntity.gd
# Description: Physical character controller for the hostile Great White Shark.
#              Manages high-frequency physics ticks, hydrodynamic tail sways, 
#              unshaded aquatic bubbles, and surface fin foam.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates exclusively visual sways, 
#   sound triggers, and particle emissions, delegating state decisions to SharkAIBehavior.
# - 120 FPS Guardrail: Computes hydrodynamic rolls, tail sways, and foam ripples
#   at 120Hz inside the physics thread to guarantee ultra-smooth movements.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SharkEntity
extends PassiveEntity

# Viewmodel and physical parameters
const SPEED_CHASE: float = 4.2
const SPEED_SWIM: float = 1.8

var player: CharacterBody3D
var _model_node: Node3D
var _model_base_y: float = 0.0
var _animation_time: float = 0.0

const COOLDOWN_ATTACK_MIN_SEC: float = 18.0
const COOLDOWN_ATTACK_MAX_SEC: float = 35.0

var _attack_sound_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 8)
	entity_habitat = 2 # Aquatic (Water only)
	name = "Entity_SHARK"


func _ready() -> void:
	# Group migration for O(1) hostile targeting sweeps
	add_to_group("hostiles")
	if is_in_group("passives"):
		remove_from_group("passives") 
	
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/shark") as Node3D
	
	if is_instance_valid(_model_node):
		GLBModelSanitizer.sanitize_model(_model_node)
		_model_base_y = _model_node.rotation.y
	
	_locate_player()
	_setup_nameplate_height()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = SharkAIBehavior.new()


## High-Frequency Physics Loop (Runs at 120Hz on the physics thread)
func _physics_tick(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	_process_procedural_swimming(delta)


func _get_entity_name_key() -> String:
	return "NPC_NAME_SHARK"


func _get_nameplate_color() -> Color:
	return Color(0.95, 0.15, 0.15) 


## Polymorphic Override (OCP/LSP Compliant): Restricts the shark strictly to Water blocks
func _is_block_type_habitable(block_type: BlockType.Type) -> bool:
	return block_type == BlockType.Type.WATER


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(7, 1)


func _play_shark_vocal() -> void:
	AudioService.play_sfx_static("shark_attack", global_position)


func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(dir.x * 6.5, 2.5, dir.z * 6.5)
		_play_shark_vocal()
		if player.has_method("take_damage"):
			player.call("take_damage", 3, knockback)


func _process_procedural_swimming(delta: float) -> void:
	if not is_instance_valid(_model_node):
		return
		
	_animation_time += delta
	var flat_velocity := Vector2(velocity.x, velocity.z)
	var speed := flat_velocity.length()
	var is_moving := speed > 0.1
	
	if is_moving:
		var swim_speed := speed * 2.8
		_model_node.rotation.y = _model_base_y + sin(_animation_time * swim_speed) * 0.22
		
		# Hydrodynamic Roll: Tilt body slightly on Z-axis when making turns
		var turn_rate := flat_velocity.angle_to(Vector2(-_model_node.global_transform.basis.z.x, -_model_node.global_transform.basis.z.z))
		var target_roll := clampf(turn_rate * 0.45, -0.35, 0.35)
		_model_node.rotation.z = lerp_angle(_model_node.rotation.z, target_roll, delta * 5.0)
		
		# Spawn glitched bubble trails from the tail periodically
		if Engine.get_physics_frames() % 10 == 0:
			_spawn_aquatic_bubble_particles()
			
		# Spawn surface foam if the dorsal fin breaks water
		if global_position.y >= 3.8: # Water surface is approx 4.0
			_spawn_surface_foam_particles()
	else:
		_model_node.rotation.y = lerp_angle(_model_node.rotation.y, _model_base_y, delta * 4.0)
		_model_node.rotation.z = lerp_angle(_model_node.rotation.z, 0.0, delta * 4.0)


func _spawn_aquatic_bubble_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 4
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.lifetime = 0.5
	
	var tail_offset := global_transform.basis.z.normalized() * 1.0
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.2
	particles.direction = Vector3.UP + tail_offset * 0.3
	particles.spread = 20.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.0
	particles.gravity = Vector3(0.0, 1.8, 0.0) # Bubbles rise upwards
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.95, 0.95, 0.6) # Translucent cyan
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	
	particles.global_position = global_position + tail_offset
	particles.emitting = true


func _spawn_surface_foam_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 3
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.4
	
	var fin_offset := global_transform.basis.z.normalized() * 0.5
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.1, 0.02, 0.2)
	particles.direction = -fin_offset
	particles.spread = 15.0
	particles.initial_velocity_min = 0.8
	particles.initial_velocity_max = 1.6
	particles.gravity = Vector3(0.0, -0.5, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.04, 0.08)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.98, 0.7) # Foam white
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	
	particles.global_position = Vector3(global_position.x, 4.0, global_position.z) + fin_offset
	particles.emitting = true


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5:
		is_panicking = true
		
	if not is_panicking:
		_attack_sound_timer -= delta
		if _attack_sound_timer <= 0.0:
			_attack_sound_timer = randf_range(COOLDOWN_ATTACK_MIN_SEC, COOLDOWN_ATTACK_MAX_SEC)
			_play_shark_vocal()
