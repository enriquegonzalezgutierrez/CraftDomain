# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Description: Physics controller for the Druid NPC. Delegating all rendering,
#              materials and animations to the Strategy pattern.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles exclusively druid 
#                conversational dialogues, keeping render tasks decoupled.
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity cleanly.
#              - Dependency Inversion Principle (DIP): Visual structures are completely 
#                delegated to the injected 'IEntityVisualRepresentation' strategy.
#              CIRCULAR DEPENDENCY SHIELD:
#              - Changed '_get_habitat()' return signature to 'int' to safely break
#                the GDScript compilation lock with MobRegistry class name.
# ==============================================================================
class_name DruidEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 4) # 4 Hearts of health
	name = "Entity_DRUID"


## Concrete Implementation (DIP): Injects the modular Druid Role ID into the strategy compiler
func _get_humanoid_role() -> int:
	return ProceduralVoxelRepresentation.RoleType.DRUID


func _get_habitat() -> int:
	return 0 # 0 = Habitat.TERRESTRIAL


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
	var is_night: bool = CelestialService.is_night_time_static()
	if is_night:
		return "DIALOGUE_DRUID_NIGHT"
		
	return "DIALOGUE_DRUID_PLAINS_A" if (npc_seed % 2 == 0) else "DIALOGUE_DRUID_PLAINS_B"


func _can_socialize() -> bool:
	return true
