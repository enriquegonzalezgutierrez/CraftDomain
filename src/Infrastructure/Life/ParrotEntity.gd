# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/ParrotEntity.gd
# Description: Physical character controller for the flying Tropical Parrot.
#              Instantiates AvianAIBehavior dynamically on ready.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates visual bobs and flight physics, 
#   delegating AI decisions to AvianAIBehavior.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ParrotEntity
extends PassiveEntity

var _animation_time: float = 0.0
var _model_node: Node3D
var _model_base_y: float = 0.0

const COOLDOWN_CHAT_MIN_SEC: float = 15.0
const COOLDOWN_CHAT_MAX_SEC: float = 25.0

const META_STATE = "avian_flight_state"

var _chat_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 2)
	entity_habitat = 0 
	name = "Entity_PARROT"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/parrot") as Node3D
	
	if is_instance_valid(_model_node):
		_model_base_y = _model_node.position.y
		GLBModelSanitizer.sanitize_model(_model_node)
	
	_setup_nameplate_height()
	_initialize_ai_behavior()


func _initialize_ai_behavior() -> void:
	if is_instance_valid(ai_component):
		ai_component.active_behavior = AvianAIBehavior.new()


func _get_entity_name_key() -> String:
	return "NPC_NAME_PARROT"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func _is_avian() -> bool:
	return true


func _can_fly() -> bool:
	return true 


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1)


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
			AudioService.play_sfx_static("parrot_squawk", global_position, 60.0)


func _animate_flight_node(delta: float) -> void:
	if not is_instance_valid(_model_node):
		return
		
	var flight_state := 0 
	if has_meta(META_STATE):
		flight_state = get_meta(META_STATE) as int
		
	if flight_state == 2:
		_model_node.position.y = _model_base_y
		_model_node.rotation = Vector3.ZERO
	else:
		_animate_soaring_model(delta)


func _animate_soaring_model(_delta: float) -> void:
	_animation_time += _delta
	var flat_velocity := Vector2(velocity.x, velocity.z)
	var is_moving := flat_velocity.length_squared() > 0.1
	var hover_bob := sin(_animation_time * 3.5) * 0.22
	
	if _is_in_showcase_viewport():
		_model_node.position.y = _model_base_y 
	else:
		_model_node.position.y = _model_base_y + hover_bob
		
	if is_moving:
		_model_node.rotation.z = sin(_animation_time * 16.0) * 0.22
		_model_node.rotation.x = deg_to_rad(12.0) 
	else:
		_model_node.rotation.z = sin(_animation_time * 1.8) * 0.04
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
		var relative_offset := _model_node.position.y - _model_base_y
		_nameplate.position.y = _collision_height + 0.35 + relative_offset
