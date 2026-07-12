# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/GrowlitheEntity.gd
# Description: Physical character controller for the loyal canine Growlithe.
#              Sanitization is delegated strictly to GLBModelSanitizer (DRY).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GrowlitheEntity
extends PassiveEntity

const COOLDOWN_BARK_MIN_SEC: float = 15.0
const COOLDOWN_BARK_MAX_SEC: float = 30.0

var _bark_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 6)
	entity_habitat = 0 
	name = "Entity_GROWLITHE"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/growlithe") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
	
	_setup_nameplate_height()


func _get_entity_name_key() -> String:
	return "NPC_NAME_GROWLITHE"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1)


func _play_flame_bark() -> void:
	velocity.y = 2.8
	AudioService.play_sfx_static("growlithe_bark", global_position, 45.0)
	_spawn_flame_bark_particles()


func _spawn_flame_bark_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 10
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.55
	
	var forward_dir := Vector3.FORWARD
	if is_instance_valid(ai_component):
		forward_dir = ai_component.wander_direction
		
	forward_dir = (forward_dir + Vector3(0.0, 0.4, 0.0)).normalized()
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.10
	particles.direction = forward_dir
	particles.spread = 20.0
	particles.initial_velocity_min = 2.5
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0.0, 2.5, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.0) 
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.0)
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	
	add_child(particles)
	particles.position = Vector3(0.0, _collision_height - 0.2, -0.15)
	particles.emitting = true


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5:
		is_panicking = true
		
	if not is_panicking:
		_bark_timer -= delta
		if _bark_timer <= 0.0:
			_bark_timer = randf_range(COOLDOWN_BARK_MIN_SEC, COOLDOWN_BARK_MAX_SEC)
			_play_flame_bark()
