# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Description: Physics controller for the tech-noir Cyber Citizen NPC, utilizing 
#              the Strategy pattern to load dynamic animations cleanly.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively dialogue 
#                and player tracking, delegating rendering to the Strategy.
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity cleanly.
#              CIRCULAR DEPENDENCY SHIELD:
#              - Replaced static class reference to 'SkeletalVisualRepresentation' with
#                dynamic 'load()' instantiation, permanently immunizing the engine 
#                against circular compile-time locks.
# ==============================================================================
class_name CyberCitizenEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/cyber/cyber_base.fbx"

var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 10)
	name = "Entity_CYBER"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_graphics_representation()
	_locate_player()
	_setup_nameplate_height()


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
	
	strategy.set("anim_idle_path", ANIM_DIR + "cyber/cyber_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "cyber/cyber_walk.fbx")
	strategy.set("anim_panic_path", ANIM_DIR + "cyber/cyber_panic.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "cyber/cyber_jump.fbx")
	
	# Bind as standard generic Resource contract
	visual_representation = strategy as IEntityVisualRepresentation
	visual_representation.build_representation(self, visual_component.body_bob_node)


func _get_humanoid_role() -> int:
	return 0 # Classified as VILLAGER for schedule loops


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "cyber_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
		hud.open_dialogue(intro_node, "NPC_NAME_ANDROID", self)


func _select_procedural_greeting_key() -> String:
	var is_night: bool = CelestialService.is_night_time_static()
	if is_night: return "DIALOGUE_CYBER_NIGHT"
	return "DIALOGUE_CYBER_PLAINS_A" if (npc_seed % 2 == 0) else "DIALOGUE_CYBER_PLAINS_B"


func _setup_floating_bubble() -> void:
	var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", tr("BUBBLE_TALK"))


func _can_socialize() -> bool:
	return true
