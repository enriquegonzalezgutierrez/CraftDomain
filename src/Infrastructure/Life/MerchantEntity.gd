# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/MerchantEntity.gd
# Description: Physical character controller for the shopkeeper Merchant NPC.
#              Manages market interactions, trade offers, and 3D visual rigs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MerchantEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/merchant.glb"
const VISUAL_STRATEGY_SCRIPT_PATH := "res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd"

## Rotation offset required for imported Blender 3D model orientation
var gaze_rotation_offset: float = PI


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 6)
	entity_habitat = 0 
	humanoid_role = 1 
	is_conversational_npc = true
	name = "Entity_MERCHANT"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_build_visual_representation()
	_setup_nameplate_height()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = MerchantAIBehavior.new()


func _build_visual_representation() -> void:
	var strategy_script := load(VISUAL_STRATEGY_SCRIPT_PATH) as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	
	visual_representation = strategy as IEntityVisualRepresentation
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.body_bob_node):
		visual_representation.build_representation(self, visual_component.body_bob_node)


func _get_entity_name_key() -> String:
	return "NPC_NAME_MERCHANT"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) 


func _is_eligible_for_quest(quest_id: String) -> bool:
	return quest_id == "fuel_fryer"


func _can_socialize() -> bool:
	return not CelestialService.is_night_time_static()


## Interaction entry point triggered by Player's VoxelInteractionComponent.
func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if not is_instance_valid(hud):
		return
		
	var intro_node := DialogueService.get_dialogue_node("merchant_intro")
	if intro_node == null:
		DialogueRegistry.initialize_dialogue_database()
		intro_node = DialogueService.get_dialogue_node("merchant_intro")
		
	if intro_node != null:
		hud.open_dialogue(intro_node, "NPC_NAME_MERCHANT", self)
