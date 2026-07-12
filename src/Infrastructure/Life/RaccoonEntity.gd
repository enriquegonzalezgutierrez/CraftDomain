# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/RaccoonEntity.gd
# Description: Physical character controller for the forest Raccoon.
#              Delegates model and material sanitization to GLBModelSanitizer (DRY).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RaccoonEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 4)
	entity_habitat = 0 
	name = "Entity_RACCOON"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/raccoon") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
	
	_setup_nameplate_height()


func _get_entity_name_key() -> String:
	return "NPC_NAME_RACCOON"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


func _play_scratching_effect(target_node: Node3D) -> void:
	if not is_instance_valid(target_node):
		return
	var look_dir := (target_node.global_position - global_position).normalized()
	look_dir.y = 0.0
	if is_instance_valid(ai_component):
		ai_component.wander_direction = look_dir
		
	var frame_stamp := Engine.get_physics_frames()
	if frame_stamp % 10 == 0:
		_spawn_claw_wood_particles(target_node.global_position)
		AudioService.play_sfx_static("footstep_wood", global_position)


func _spawn_claw_wood_particles(target_pos: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 4
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.40
	
	var direction_vec := (global_position - target_pos).normalized()
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.1
	particles.direction = direction_vec
	particles.spread = 30.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 2.5
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.03, 0.03)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.3, 0.15) 
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(particles)
		particles.global_position = global_position.lerp(target_pos, 0.6) + Vector3(0.0, 0.2, 0.0)
		particles.emitting = true
