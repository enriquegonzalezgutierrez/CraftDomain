# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/QuiqueEntity.gd
# Description: Physical character controller for Quique the Noble, living legend
#              and vanquisher of Weaver Malakor. Coordinates interactive lore 
#              branching dialogues and strategic campaign secrets.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name QuiqueEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/quique/quique.glb"

var gaze_rotation_offset: float = 0.0
var player: CharacterBody3D
var _model_node: Node3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 10)
	entity_habitat = 0 
	humanoid_role = 0 
	is_conversational_npc = true
	name = "Entity_QUIQUE"


func _ready() -> void:
	add_to_group("passives")
	_bind_scene_components()
	_sanitize_visual_model()
	_setup_nameplate_height()
	_initialize_ai_behavior()
	_initialize_quique_dialogue_nodes()


func _initialize_ai_behavior() -> void:
	if is_instance_valid(ai_component):
		ai_component.active_behavior = QuiqueAIBehavior.new()


func _bind_scene_components() -> void:
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent


func _sanitize_visual_model() -> void:
	_model_node = get_node_or_null("Visuals/BodyBobJoint/quique") as Node3D
	if is_instance_valid(_model_node):
		GLBModelSanitizer.sanitize_model(_model_node)


func _get_entity_name_key() -> String:
	return "NPC_NAME_QUIQUE"


func _get_nameplate_color() -> Color:
	return Color(0.85, 0.65, 0.15)


func _has_ui_decorations() -> bool:
	return true


func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueService.get_dialogue_node("quique_intro")
		if intro_node == null:
			_initialize_quique_dialogue_nodes()
			intro_node = DialogueService.get_dialogue_node("quique_intro")
			
		if intro_node != null:
			AudioService.play_sfx_static("npc_chat", global_position)
			hud.open_dialogue(intro_node, "NPC_NAME_QUIQUE", self)


func _initialize_quique_dialogue_nodes() -> void:
	var intro_node := DialogueNode.new()
	intro_node.node_id = "quique_intro"
	intro_node.text = "DIALOGUE_QUIQUE_INTRO"
	intro_node.choices = [
		_create_choice("DIALOGUE_QUIQUE_CHOICE_MALAKOR", "quique_secret"),
		_create_choice("DIALOGUE_QUIQUE_CHOICE_STORY", "quique_story"),
		_create_choice("DIALOGUE_MERCHANT_CHOICE_CLOSE", "")
	]
	
	var story_node := DialogueNode.new()
	story_node.node_id = "quique_story"
	story_node.text = "DIALOGUE_QUIQUE_STORY_TEXT"
	story_node.choices = [
		_create_choice("DIALOGUE_QUIQUE_CHOICE_MALAKOR", "quique_secret"),
		_create_choice("DIALOGUE_MERCHANT_CHOICE_BACK", "quique_intro")
	]
	
	var secret_node := DialogueNode.new()
	secret_node.node_id = "quique_secret"
	secret_node.text = "DIALOGUE_QUIQUE_SECRET_TEXT"
	secret_node.choices = [
		_create_choice("DIALOGUE_QUIQUE_CHOICE_THANK_YOU", "")
	]
	
	DialogueRegistry.register_dialogue_node(intro_node)
	DialogueRegistry.register_dialogue_node(story_node)
	DialogueRegistry.register_dialogue_node(secret_node)


func _create_choice(option_key: String, target_id: String) -> DialogueChoice:
	var choice := DialogueChoice.new()
	choice.option_text = option_key
	choice.target_node_id = target_id
	return choice
