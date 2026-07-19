# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/GoblinEntity.gd
# Description: Physical character controller for the hostile skirmisher Goblin.
#              Manages high-frequency physics ticks, inventory thievery transactions,
#              agile escape jumps, and unshaded golden spark trail particles.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates exclusively visual sways, 
#   sound triggers, and particle emissions, delegating state decisions to GoblinAIBehavior.
# - Dependency Inversion Principle (DIP): Uses local decoupled metadata keys 
#   to break Godot 4's cyclic preloader compile locks with its behavior script.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GoblinEntity
extends PassiveEntity

var player: CharacterBody3D

const COOLDOWN_GIGGLE_MIN_SEC: float = 12.0
const COOLDOWN_GIGGLE_MAX_SEC: float = 24.0

## Decoupled local metadata key to prevent cyclic compile locks with GoblinAIBehavior
const META_GOBLIN_STATE = "goblin_local_state"

var _giggle_timer: float = randf_range(4.0, 10.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 4)
	entity_habitat = 0 # Terrestrial
	name = "Entity_GOBLIN"


func _ready() -> void:
	add_to_group("hostiles")
	if is_in_group("passives"):
		remove_from_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/goblin") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
	
	_locate_player()
	_setup_nameplate_height()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = GoblinAIBehavior.new()


func _build_visual_representation() -> void:
	pass


func _get_entity_name_key() -> String:
	return "NPC_NAME_GOBLIN"


func _get_nameplate_color() -> Color:
	return Color(0.95, 0.15, 0.15)


func _can_socialize() -> bool:
	return true


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(1, 1)


func _bite_player() -> void:
	if not is_instance_valid(player):
		return
		
	var dir := (player.global_position - global_position).normalized()
	var knockback := Vector3(dir.x * 4.5, 0.25, dir.z * 4.5)
	
	if player.has_method("take_damage"):
		player.call("take_damage", 1, knockback) 
		
	AudioService.play_sfx_static("goblin_cackle", global_position)
	
	var inv: IInventory = player.get("inventory") as IInventory
	if is_instance_valid(inv):
		if inv.get_item_total_quantity(1) > 0:
			inv.consume_item(1, 1)


## High-Frequency Physics Loop (120Hz Guardrail)
func _physics_tick(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var state := 0
	if has_meta(META_GOBLIN_STATE):
		state = get_meta(META_GOBLIN_STATE) as int
		
	if state == 2: # STATE_RETREATING (Hit-and-Run)
		_process_agile_escape_acrobatics(delta)


func _process_agile_escape_acrobatics(_delta: float) -> void:
	var flat_velocity := Vector2(velocity.x, velocity.z)
	var is_moving := flat_velocity.length_squared() > 0.1
	
	if is_moving:
		if Engine.get_physics_frames() % 30 == 0 and is_on_floor():
			velocity.y = 4.5
			
		if Engine.get_physics_frames() % 12 == 0:
			_spawn_gold_sparks()


func _spawn_gold_sparks() -> void:
	var particles := CPUParticles3D.new()
	_configure_spark_particle_properties(particles)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2) # Shiny golden loot
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	
	particles.global_position = global_position + Vector3(0.0, 0.4, 0.0)
	particles.emitting = true


func _configure_spark_particle_properties(particles: CPUParticles3D) -> void:
	particles.amount = 3
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.45
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.15
	particles.direction = Vector3.UP
	particles.spread = 45.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 3.5
	particles.gravity = Vector3(0.0, -9.8, 0.0)


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5:
		is_panicking = true
		
	if not is_panicking:
		_giggle_timer -= delta
		if _giggle_timer <= 0.0:
			_giggle_timer = randf_range(COOLDOWN_GIGGLE_MIN_SEC, COOLDOWN_GIGGLE_MAX_SEC)
			AudioService.play_sfx_static("goblin_cackle", global_position, 40.0)
