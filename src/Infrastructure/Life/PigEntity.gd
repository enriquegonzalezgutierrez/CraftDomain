# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/PigEntity.gd
# Description: Physical character controller for the passive grasslands Pig.
#              Sanitization is delegated strictly to GLBModelSanitizer (DRY).
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
