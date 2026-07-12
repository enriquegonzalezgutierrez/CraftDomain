# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/GolemEntity.gd
# Description: Physical character controller for the village protector Iron Golem.
#              Delegates model and material sanitization to GLBModelSanitizer (DRY).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GolemEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 30)
	entity_habitat = 0 
	name = "Entity_GOLEM"


func _ready() -> void:
	add_to_group("passives")
	
	var alert_net := AlertNetworkService.instance
	if is_instance_valid(alert_net):
		alert_net.register_defender(self)
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/golem") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
	
	_setup_nameplate_height()


func _get_entity_name_key() -> String:
	return "NPC_NAME_GOLEM"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func _has_ui_decorations() -> bool:
	return true


func _can_socialize() -> bool:
	return false 


func _is_avian() -> bool:
	return false


func _execute_heavy_combat_strike(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var target_dir := (target.global_position - global_position).normalized()
	target_dir.y = 0.0
	var throw_force := target_dir * 3.5 + Vector3(0.0, 9.5, 0.0)
	if target.has_method("take_damage"):
		target.call("take_damage", 2, throw_force, self)
