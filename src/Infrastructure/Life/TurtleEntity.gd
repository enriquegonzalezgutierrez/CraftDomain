# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/TurtleEntity.gd
# Description: Physical character controller for the Amphibious Sea Turtle.
#              Instantiates AmphibiousAIBehavior dynamically on ready.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates physical translations,
#   coastal boundaries, and visual sanitization, binding to AmphibiousAIBehavior.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name TurtleEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 4)
	entity_habitat = 1 # Amphibious (Water, Sand, Mud)
	name = "Entity_TURTLE"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/turtle") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
	
	_setup_nameplate_height()
	_initialize_ai_behavior()


func _initialize_ai_behavior() -> void:
	if is_instance_valid(ai_component):
		ai_component.active_behavior = AmphibiousAIBehavior.new()


func _get_entity_name_key() -> String:
	return "NPC_NAME_TURTLE"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func _is_block_type_habitable(block_type: BlockType.Type) -> bool:
	return (
		block_type == BlockType.Type.WATER or 
		block_type == BlockType.Type.SAND or 
		block_type == BlockType.Type.MUD or
		block_type == BlockType.Type.AIR
	)


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(7, 1)


func _is_avian() -> bool:
	return false
