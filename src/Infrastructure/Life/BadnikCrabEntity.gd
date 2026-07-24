# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/BadnikCrabEntity.gd
# Description: Physical character controller for the hostile Robotic Badnik Crab.
#              Instantiates ZombieAIBehavior dynamically on ready.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name BadnikCrabEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 8)
	entity_habitat = 0 # Terrestrial
	name = "Entity_BADNIK_CRAB"


func _ready() -> void:
	add_to_group("hostiles")
	if is_in_group("passives"):
		remove_from_group("passives")
		
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/badnik_crab") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
		
	_setup_nameplate_height()
	_initialize_ai_behavior()


func _initialize_ai_behavior() -> void:
	if is_instance_valid(ai_component):
		ai_component.active_behavior = ZombieAIBehavior.new()


func _get_entity_name_key() -> String:
	return "NPC_NAME_BADNIK_CRAB"


func _get_nameplate_color() -> Color:
	return Color(0.95, 0.15, 0.15)


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(1, 2)
