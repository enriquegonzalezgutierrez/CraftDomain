# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/MinerEntity.gd
# Description: Physical character controller for the cavern Miner NPC.
#              Manages mining routines, subterranean dialogues, and 3D rigs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MinerEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/miner.glb"
const VISUAL_STRATEGY_SCRIPT_PATH := "res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd"

var gaze_rotation_offset: float = PI
var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 8)
	entity_habitat = 0 
	name = "Entity_MINER"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_graphics_representation()
	_locate_player()
	_setup_nameplate_height()
	_initialize_ai_behavior()


func _initialize_ai_behavior() -> void:
	if is_instance_valid(ai_component):
		ai_component.active_behavior = MinerAIBehavior.new()


func _setup_graphics_representation() -> void:
	var strategy_script := load(VISUAL_STRATEGY_SCRIPT_PATH) as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	
	visual_representation = strategy as IEntityVisualRepresentation
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.body_bob_node):
		visual_representation.build_representation(self, visual_component.body_bob_node)


func _get_entity_name_key() -> String:
	return "NPC_NAME_MINER"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) 


func _get_humanoid_role() -> int:
	return 4 


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "miner_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
		hud.open_dialogue(intro_node, "NPC_NAME_MINER", self)


func _select_procedural_greeting_key() -> String:
	if CelestialService.is_night_time_static():
		return "DIALOGUE_MINER_NIGHT"
		
	var variety_index := npc_seed % 2
	if variety_index == 0: return "DIALOGUE_MINER_PLAINS_A"
	return "DIALOGUE_MINER_PLAINS_B"


func _can_socialize() -> bool:
	return true
