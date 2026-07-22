# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/ElephantEntity.gd
# Description: Physical character controller for the Colossal Elephant.
#              Instantiates ElephantAIBehavior dynamically on ready.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates physical interactions 
#   and heavy step impacts, binding to ElephantAIBehavior.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ElephantEntity
extends PassiveEntity

const COOLDOWN_CHAT_MIN_SEC: float = 25.0
const COOLDOWN_CHAT_MAX_SEC: float = 45.0

var _chat_timer: float = randf_range(8.0, 20.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 20)
	entity_habitat = 0 
	name = "Entity_ELEPHANT"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/elephant") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
	
	_setup_nameplate_height()
	_initialize_ai_behavior()


func _initialize_ai_behavior() -> void:
	if is_instance_valid(ai_component):
		ai_component.active_behavior = ElephantAIBehavior.new()


func _get_entity_name_key() -> String:
	return "NPC_NAME_ELEPHANT"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func take_damage(amount: int, _knockback_force: Vector3, attacker: Node = null) -> void:
	super(amount, Vector3.ZERO, attacker)


func _on_domain_entity_took_damage(amount: int) -> void:
	super(amount)
	velocity.y = JUMP_VELOCITY * 0.75


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 2)
	inv.add_item(1, 1)


func _play_heavy_step_impact() -> void:
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		var player_node := parent_node.get_node_or_null("Player") as CharacterBody3D
		if is_instance_valid(player_node):
			var dist := global_position.distance_to(player_node.global_position)
			if dist < 12.0:
				var intensity := remap(dist, 0.0, 12.0, 0.18, 0.02)
				player_node.set("_shake_intensity", intensity)
				
	AudioService.play_sfx_static("footstep_stone", global_position)


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
			AudioService.play_sfx_static("elephant_chatter", global_position, 75.0)
