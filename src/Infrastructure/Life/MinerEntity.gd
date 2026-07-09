# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: MinerEntity
# Description: Physical character controller for the cave Miner NPC.
#              It delegates all coal scanning, mining decision trees, and 
#              rock extraction routines to the decoupled MinerAIBehavior strategy, 
#              focusing on physical Translations, skeletal attachments, and chat.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   movement, custom mesh alignments, and dialogue tree interactions.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, utilizing its parent physics process and signals.
# - Dependency Inversion Principle (DIP): Injects the MinerAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MinerEntity.gd
# ==============================================================================
class_name MinerEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/miner/miner_base.fbx"

# Sibling node references
var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Miners spawn with 4 Hearts of health (8 HP)
	super(spawn_pos, 8)
	name = "Entity_MINER"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_graphics_representation()
	_locate_player()
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Cave Miner AI strategy dynamically on ready,
	# completely overriding the default generic civilian schedules.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = MinerAIBehavior.new()


## Binds the Skeletal strategy dynamically to avoid static compiler circular dependency locks
func _setup_graphics_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	strategy.set("scale_multiplier", Vector3(0.8856, 0.8856, 0.8856))
	strategy.set("position_offset", Vector3.ZERO)
	strategy.set("rotation_offset", Vector3(0, 180, 0))
	
	# Load concrete animation tracks
	strategy.set("anim_idle_path", ANIM_DIR + "miner/miner_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "miner/miner_walk.fbx")
	strategy.set("anim_attack_path", ANIM_DIR + "miner/miner_attack.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "miner/miner_jump.fbx")
	
	# Bind as standard visual representation
	visual_representation = strategy as IEntityVisualRepresentation
	visual_representation.build_representation(self, visual_component.body_bob_node)


func _get_humanoid_role() -> int:
	return 0 # Classified as VILLAGER for schedule loops


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


# ==============================================================================
# CONVERSATION BARK & DIALOGUES
# ==============================================================================
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
	return "DIALOGUE_MINER_PLAINS_A" if (npc_seed % 2 == 0) else "DIALOGUE_MINER_PLAINS_B"


func _setup_floating_bubble() -> void:
	var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", tr("BUBBLE_TALK"))


func _can_socialize() -> bool:
	return true
