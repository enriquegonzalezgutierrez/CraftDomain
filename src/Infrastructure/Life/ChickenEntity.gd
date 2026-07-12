# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/ChickenEntity.gd
# Description: Physical character controller for the passive Prairie Chicken.
#              Sanitization is delegated strictly to GLBModelSanitizer (DRY).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChickenEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 2)
	entity_habitat = 0 
	name = "Entity_CHICKEN"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/chicken") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
		
	_setup_nameplate_height()


func _get_entity_name_key() -> String:
	return "NPC_NAME_CHICKEN"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1) # Chicken meat


func _is_avian() -> bool:
	return true
