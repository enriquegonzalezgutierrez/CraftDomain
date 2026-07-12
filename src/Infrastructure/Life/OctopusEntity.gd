# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/OctopusEntity.gd
# Description: Physical character controller for the aquatic Octopus.
#              Delegates model and material sanitization to GLBModelSanitizer (DRY).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name OctopusEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 6)
	entity_habitat = 2 # Aquatic (Water only)
	name = "Entity_OCTOPUS"


func _ready() -> void:
	add_to_group("passives")
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/octopus") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
	
	_setup_nameplate_height()
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	if not is_instance_valid(ai_component):
		ai_component = NPCAIComponent.new()
		add_child(ai_component)
		
	if is_instance_valid(ai_component):
		ai_component.active_behavior = OctopusAIBehavior.new()


func _get_entity_name_key() -> String:
	return "NPC_NAME_OCTOPUS"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(7, 1) # Sand


func _is_avian() -> bool:
	return true 


func _can_socialize() -> bool:
	return true
