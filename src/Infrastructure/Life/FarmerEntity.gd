# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/FarmerEntity.gd
# Description: Physical character controller representing an agricultural Farmer NPC.
#              Manages crop interactions, farm routines, and 3D visual rigs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FarmerEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/farmer.glb"
const VISUAL_STRATEGY_SCRIPT_PATH := "res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd"

var gaze_rotation_offset: float = PI
var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 6)
	entity_habitat = 0 
	humanoid_role = 3 
	is_conversational_npc = true
	name = "Entity_FARMER"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_build_visual_representation()
	_locate_player()
	_setup_nameplate_height()
	_initialize_ai_behavior()


func _initialize_ai_behavior() -> void:
	if is_instance_valid(ai_component):
		ai_component.active_behavior = FarmerAIBehavior.new()


func _build_visual_representation() -> void:
	var strategy_script := load(VISUAL_STRATEGY_SCRIPT_PATH) as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	
	visual_representation = strategy as IEntityVisualRepresentation
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.body_bob_node):
		visual_representation.build_representation(self, visual_component.body_bob_node)


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _get_entity_name_key() -> String:
	return "NPC_NAME_FARMER"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) 


func _is_eligible_for_quest(_quest_id: String) -> bool:
	return false 


func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "farmer_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
		hud.open_dialogue(intro_node, "NPC_NAME_FARMER", self)


func _select_procedural_greeting_key() -> String:
	if CelestialService.is_night_time_static():
		return "DIALOGUE_FARMER_NIGHT"
		
	var biome_id := BiomeService.get_biome_id_at_position(global_position, get_parent())
	match biome_id:
		4: return "DIALOGUE_FARMER_GLACIERS"   
		7: return "DIALOGUE_FARMER_NEON"       
		_:
			var variety_index := npc_seed % 2
			if variety_index == 0: return "DIALOGUE_FARMER_PLAINS_A"
			return "DIALOGUE_FARMER_PLAINS_B"
