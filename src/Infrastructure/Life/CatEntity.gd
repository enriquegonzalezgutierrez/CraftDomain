# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/CatEntity.gd
# Description: Physical character controller for the domestic companion Cat.
#              Instantiates CatAIBehavior dynamically on ready.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates physical interactions 
#   and visual sanitization, binding to CatAIBehavior.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CatEntity
extends PassiveEntity

const COOLDOWN_MEOW_MIN_SEC: float = 15.0
const COOLDOWN_MEOW_MAX_SEC: float = 30.0

var _meow_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 4)
	entity_habitat = 0 
	name = "Entity_CAT"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/cat") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
	
	_setup_nameplate_height()
	_initialize_ai_behavior()


func _initialize_ai_behavior() -> void:
	if is_instance_valid(ai_component):
		ai_component.active_behavior = CatAIBehavior.new()


func _get_entity_name_key() -> String:
	return "NPC_NAME_CAT"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) 


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1)


func _play_alarm_hiss(zombie_node: CharacterBody3D) -> void:
	if not is_instance_valid(zombie_node):
		return
	velocity.y = 3.5
	var look_dir := (zombie_node.global_position - global_position).normalized()
	look_dir.y = 0.0
	if is_instance_valid(ai_component):
		ai_component.wander_direction = look_dir
		
	AudioService.play_sfx_static("npc_chat", global_position)
	_spawn_hiss_alert_particles()


func _spawn_hiss_alert_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 8
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.45
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.15
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 35.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 2.5
	particles.gravity = Vector3(0.0, 1.5, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.15, 0.15) 
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	
	add_child(particles)
	particles.position = Vector3(0.0, _collision_height + 0.1, 0.0)
	particles.emitting = true


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5:
		is_panicking = true
		
	if not is_panicking:
		_meow_timer -= delta
		if _meow_timer <= 0.0:
			_meow_timer = randf_range(COOLDOWN_MEOW_MIN_SEC, COOLDOWN_MEOW_MAX_SEC)
			AudioService.play_sfx_static("cat_meow", global_position, 40.0)
