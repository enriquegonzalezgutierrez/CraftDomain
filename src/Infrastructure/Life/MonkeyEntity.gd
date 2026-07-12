# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/MonkeyEntity.gd
# Description: Physical character controller for the acrobatic Tropical Monkey.
#              Sanitization is delegated strictly to GLBModelSanitizer (DRY).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MonkeyEntity
extends PassiveEntity

const COOLDOWN_CHAT_MIN_SEC: float = 15.0
const COOLDOWN_CHAT_MAX_SEC: float = 25.0

var _chat_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 6)
	entity_habitat = 0 
	name = "Entity_MONKEY"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/monkey") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
	
	_setup_nameplate_height()


func _get_entity_name_key() -> String:
	return "NPC_NAME_MONKEY"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1)


func _play_monkey_chatter() -> void:
	AudioService.play_sfx_static("monkey_chatter", global_position, 55.0)


func _play_backflip_effect() -> void:
	velocity.y = JUMP_VELOCITY * 1.3
	
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.visual_root):
		var flip_tween := create_tween()
		var start_rot_x: float = visual_component.visual_root.rotation.x
		flip_tween.tween_property(visual_component.visual_root, "rotation:x", start_rot_x - TAU, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		flip_tween.chain().tween_callback(func() -> void:
			if is_instance_valid(visual_component) and is_instance_valid(visual_component.visual_root):
				visual_component.visual_root.rotation.x = start_rot_x 
		)
		
	AudioService.play_sfx_static("npc_chat", global_position)


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
			_play_monkey_chatter()
