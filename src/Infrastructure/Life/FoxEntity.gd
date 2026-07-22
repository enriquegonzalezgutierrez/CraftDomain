# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/FoxEntity.gd
# Description: Physical character controller for the forest predator Fox.
#              Instantiates FoxAIBehavior dynamically on ready.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates physical interactions 
#   and visual animations, binding to FoxAIBehavior.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FoxEntity
extends PassiveEntity

const COOLDOWN_CHAT_MIN_SEC: float = 20.0
const COOLDOWN_CHAT_MAX_SEC: float = 35.0

var _chat_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 4)
	entity_habitat = 0 
	name = "Entity_FOX"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/fox") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
	
	_setup_nameplate_height()
	_initialize_ai_behavior()


func _initialize_ai_behavior() -> void:
	if is_instance_valid(ai_component):
		ai_component.active_behavior = FoxAIBehavior.new()


func _get_entity_name_key() -> String:
	return "NPC_NAME_FOX"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func _on_domain_entity_took_damage(amount: int) -> void:
	super(amount)
	velocity.y = JUMP_VELOCITY


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1)


func _set_crouch_height(is_crouched: bool) -> void:
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.visual_root):
		var target_scale_y := 0.65 if is_crouched else 1.0
		var target_pos_y := 0.01 if is_crouched else 0.02
		visual_component.visual_root.scale.y = lerp(visual_component.visual_root.scale.y, target_scale_y, 0.12)
		visual_component.visual_root.position.y = lerp(visual_component.visual_root.position.y, target_pos_y, 0.12)


func _execute_pounce_strike(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	AudioService.play_sfx_static("fox_screech", global_position, 35.0)
	if target.has_method("take_damage"):
		var direction_vec := (target.global_position - global_position).normalized()
		var pounce_knockback := direction_vec * 4.2 + Vector3(0.0, 1.8, 0.0)
		target.call("take_damage", 2, pounce_knockback, self)


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5:
		is_panicking = true
		
	if not is_panicking:
		_chat_timer -= delta
		if _chat_timer <= 0.0:
			_chat_timer = randf_range(COOLDOWN_CHAT_MIN_SEC, COOLDOWN_CHAT_MAX_SEC)
			AudioService.play_sfx_static("fox_screech", global_position, 45.0)
