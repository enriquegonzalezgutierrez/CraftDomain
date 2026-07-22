# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/BirdEntity.gd
# Description: Physical character controller and flight physics simulator 
#              for the flying Yellow Bird. Instantiates AvianAIBehavior dynamically.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates visual bobs and flight physics, 
#   delegating AI decisions to AvianAIBehavior.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name BirdEntity
extends PassiveEntity

const MODEL_BASE_Y: float = 0.0
const COOLDOWN_CHAT_MIN_SEC: float = 15.0
const COOLDOWN_CHAT_MAX_SEC: float = 25.0

const FLIGHT_SPEED_SOAR: float = 3.2
const FLIGHT_SPEED_GLIDE: float = 4.8
const PERCH_DURATION_SEC: float = 5.0

const META_STATE = "avian_flight_state"
const META_TARGET_LEAF = "avian_leaf_target"
const META_REST_TIMER = "avian_rest_timer"

var _animation_time: float = 0.0
var _model_node: Node3D
var _chat_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 2)
	entity_habitat = 0 
	name = "Entity_BIRD"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/yellow_bird") as Node3D
	
	if is_instance_valid(_model_node):
		GLBModelSanitizer.sanitize_model(_model_node)
	
	_setup_nameplate_height()
	_initialize_ai_behavior()


func _initialize_ai_behavior() -> void:
	if is_instance_valid(ai_component):
		ai_component.active_behavior = AvianAIBehavior.new()


func _get_entity_name_key() -> String:
	return "NPC_NAME_BIRD"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) 


func _is_avian() -> bool: 
	return true


func _can_fly() -> bool:
	return true 


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1)


func _physics_tick(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var flight_state := 0
	if has_meta(META_STATE):
		flight_state = get_meta(META_STATE) as int
		
	match flight_state:
		2:
			_process_perched_physics(delta)
		1:
			_process_landing_physics(delta)
		0:
			_process_soaring_physics(delta)


func _process_perched_physics(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= gravity * 0.2 * delta
	else:
		velocity.y = -0.1


func _process_landing_physics(delta: float) -> void:
	var target_leaf: Vector3i = get_meta(META_TARGET_LEAF) if has_meta(META_TARGET_LEAF) else Vector3i(0, -999, 0)
	if target_leaf.y == -999:
		return
		
	var target_pos := Vector3(target_leaf) + Vector3(0.5, 1.05, 0.5)
	var diff := target_pos - global_position
	
	if diff.length_squared() > 0.4:
		var glide_dir := diff.normalized()
		velocity.x = glide_dir.x * FLIGHT_SPEED_GLIDE
		velocity.z = glide_dir.z * FLIGHT_SPEED_GLIDE
		velocity.y = lerp(velocity.y, glide_dir.y * FLIGHT_SPEED_GLIDE, delta * 6.0)
	else:
		velocity.x = 0.0; velocity.z = 0.0; velocity.y = 0.0
		set_meta(META_STATE, 2)
		set_meta(META_REST_TIMER, PERCH_DURATION_SEC)


func _process_soaring_physics(delta: float) -> void:
	var ai := ai_component
	if not is_instance_valid(ai): return
		
	var is_panicking := ai.get("current_task") as int == 5
	var time_sec := float(Time.get_ticks_msec()) / 1000.0
	
	var speed := FLIGHT_SPEED_SOAR * (2.2 if is_panicking else 1.0)
	var freq := 0.8 if is_panicking else 0.45
	var soar_dir := Vector3(sin(time_sec * freq), 0.0, cos(time_sec * freq)).normalized()
	
	var target_y := 22.0 if is_panicking else 18.0
	var vertical_drift := (target_y - global_position.y) * 0.15
	var wave_offset := sin(time_sec * 2.5) * 0.25
	
	velocity.x = soar_dir.x * speed
	velocity.z = soar_dir.z * speed
	velocity.y = lerp(velocity.y, vertical_drift + wave_offset, delta * 4.0)
	
	ai.set("wander_direction", soar_dir)


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	_process_ambient_chatter(delta)
	_animate_flight_node(delta)
	_update_nameplate_position()


func _process_ambient_chatter(delta: float) -> void:
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5:
		is_panicking = true
		
	if not is_panicking:
		_chat_timer -= delta
		if _chat_timer <= 0.0:
			_chat_timer = randf_range(COOLDOWN_CHAT_MIN_SEC, COOLDOWN_CHAT_MAX_SEC)
			AudioService.play_sfx_static("bird_chatter", global_position, 60.0)


func _animate_flight_node(delta: float) -> void:
	if not is_instance_valid(_model_node):
		return
		
	var flight_state := 0 
	if has_meta(META_STATE):
		flight_state = get_meta(META_STATE) as int
		
	if flight_state == 2:
		_model_node.position.y = MODEL_BASE_Y
		_model_node.rotation = Vector3.ZERO
	else:
		_animate_soaring_model(delta)


func _animate_soaring_model(_delta: float) -> void:
	_animation_time += _delta
	var flat_velocity := Vector2(velocity.x, velocity.z)
	var is_moving := flat_velocity.length_squared() > 0.1
	var hover_bob := sin(_animation_time * 4.0) * 0.18
	
	if _is_in_showcase_viewport():
		_model_node.position.y = MODEL_BASE_Y 
	else:
		_model_node.position.y = MODEL_BASE_Y + hover_bob
		
	if is_moving:
		_model_node.rotation.z = sin(_animation_time * 16.0) * 0.22
		_model_node.rotation.x = deg_to_rad(10.0) 
	else:
		_model_node.rotation.z = sin(_animation_time * 2.0) * 0.05
		_model_node.rotation.x = 0.0


func _is_in_showcase_viewport() -> bool:
	var current_node := get_parent()
	while current_node != null:
		if current_node is SubViewport and current_node.name != "root":
			return true
		current_node = current_node.get_parent()
	return false


func _update_nameplate_position() -> void:
	if is_instance_valid(_nameplate) and is_instance_valid(_model_node):
		var relative_offset := _model_node.position.y - MODEL_BASE_Y
		_nameplate.position.y = _collision_height + 0.35 + relative_offset
