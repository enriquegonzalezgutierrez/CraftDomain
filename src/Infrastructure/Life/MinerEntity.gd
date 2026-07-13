# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/MinerEntity.gd
# Description: Physical character controller for the cave Miner NPC.
#              Corrected: Implemented missing _get_entity_name_key virtual contract.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MinerEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/miner/miner_base.fbx"
var gaze_rotation_offset: float = PI
var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 8)
	entity_habitat = 0 # Terrestrial
	name = "Entity_MINER"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_graphics_representation()
	_locate_player()
	_setup_nameplate_height()
	
	# Symmetrical lifecycle initialization call (Resolves missing nameplate)
	_execute_lifecycle_initialization()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = MinerAIBehavior.new()


func _setup_graphics_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	strategy.set("anim_idle_path", ANIM_DIR + "miner/miner_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "miner/miner_walk.fbx")
	strategy.set("anim_attack_path", ANIM_DIR + "miner/miner_attack.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "miner/miner_jump.fbx")
	
	visual_representation = strategy as IEntityVisualRepresentation
	visual_representation.build_representation(self, visual_component.body_bob_node)


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _get_entity_name_key() -> String:
	return "NPC_NAME_MINER"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Friendly/Passive Green (LSP Compliant)


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
	var is_night: bool = CelestialService.is_night_time_static()
	if is_night: 
		return "DIALOGUE_MINER_NIGHT"
		
	# Centralized DRY Biome Sensing
	var _biome_id := BiomeService.get_biome_id_at_position(global_position, get_parent())
	var variety_index := npc_seed % 2
	if variety_index == 0:
		return "DIALOGUE_MINER_PLAINS_A"
	return "DIALOGUE_MINER_PLAINS_B"


func _can_socialize() -> bool:
	return true
