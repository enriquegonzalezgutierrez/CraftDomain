# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/TurtleEntity.gd
# Description: Physical character controller for the Amphibious Sea Turtle.
#              Sustains strict shore and water limits polimorphically (OCP/LSP).
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


func _get_entity_name_key() -> String:
	return "NPC_NAME_TURTLE"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


## Polymorphic Override (OCP/LSP Compliant): Restricts the turtle to shore and ocean blocks
func _is_block_type_habitable(block_type: BlockType.Type) -> bool:
	return (
		block_type == BlockType.Type.WATER or 
		block_type == BlockType.Type.SAND or 
		block_type == BlockType.Type.MUD
	)


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(7, 1) # Sand block


func _is_avian() -> bool:
	return true
