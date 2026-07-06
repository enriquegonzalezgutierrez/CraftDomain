# ==============================================================================
# Project: CraftDomain
# Description: Druid NPC physics controller with dynamic visual strategy injection.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles exclusively druid 
#                conversational dialogues, delegating all rendering/mesh tasks.
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity cleanly.
#              - Dependency Inversion Principle (DIP): Visual structures are completely 
#                delegated to the injected `IEntityVisualRepresentation` strategy.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/DruidEntity.gd
# ==============================================================================
class_name DruidEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 4) # 4 Hearts of health
	name = "Entity_DRUID"


## Concrete Implementation (DIP): Injects the modular Druid Role ID into the strategy compiler
func _get_humanoid_role() -> int:
	return ProceduralVoxelRepresentation.RoleType.DRUID


func _setup_floating_bubble() -> void:
	var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", tr("BUBBLE_TALK"))


## Public Gaze Interaction: Localized dialogue trees.
func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "druid_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
			
		hud.open_dialogue(intro_node, "NPC_NAME_DRUID", self)


## Selects a unique localized dialogue key based on time, biome, and variety index.
func _select_procedural_greeting_key() -> String:
	# DIP Compliance: Safely retrieve time statically
	var is_night: bool = CelestialService.is_night_time_static()
		
	if is_night:
		return "DIALOGUE_DRUID_NIGHT"
		
	return "DIALOGUE_DRUID_PLAINS_A" if (npc_seed % 2 == 0) else "DIALOGUE_DRUID_PLAINS_B"


func _can_socialize() -> bool:
	return true
