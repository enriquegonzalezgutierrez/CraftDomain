# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/SpeedyHedgehogEntity.gd
# Description: Physical character controller for the Speedy Blue Hedgehog mascot.
#              Instantiates HedgehogAIBehavior dynamically on ready.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SpeedyHedgehogEntity
extends PassiveEntity

const HEDGEHOG_RUN_SPEED: float = 6.8


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 6)
	entity_habitat = 0 # Terrestrial
	name = "Entity_SPEEDY_HEDGEHOG"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/speedy_hedgehog") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
		
	_setup_nameplate_height()
	_initialize_ai_behavior()


func _initialize_ai_behavior() -> void:
	if is_instance_valid(ai_component):
		ai_component.active_behavior = HedgehogAIBehavior.new()


func _get_entity_name_key() -> String:
	return "NPC_NAME_SPEEDY_HEDGEHOG"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(1, 2)
