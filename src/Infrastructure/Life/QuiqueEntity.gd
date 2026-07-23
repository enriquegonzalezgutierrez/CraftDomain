# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/QuiqueEntity.gd
# Description: Physical character controller for Quique, the Castle Resident.
#              Utilizes native GLB model sanitization and GOAP AI behaviors.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates physical translations,
#   GLB model sanitization, and dialogue triggers.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 10 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name QuiqueEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/quique/quique.glb"

# Model is oriented correctly forward in the .tscn scene
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
		var intro_node := DialogueNode.new()
		intro_node.node_id = "quique_intro_temp"
		intro_node.text = "DIALOGUE_QUIQUE_GREETING"
		
		AudioService.play_sfx_static("npc_chat", global_position)
		hud.open_dialogue(intro_node, "NPC_NAME_QUIQUE", self)
