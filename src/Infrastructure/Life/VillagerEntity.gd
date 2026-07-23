# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/VillagerEntity.gd
# Description: Physical character controller for the common Gossip Villager NPC.
#              Manages dialogue interactions, quest completions, and 3D visual rigs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VillagerEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/villager.glb"
const VISUAL_STRATEGY_SCRIPT_PATH := "res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd"

# Model is oriented correctly forward in the .tscn scene
var gaze_rotation_offset: float = 0.0
var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 6)
	entity_habitat = 0 
	humanoid_role = 0 
	is_conversational_npc = true
	name = "Entity_VILLAGER"


func _ready() -> void:
	add_to_group("passives")
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_build_visual_representation()
	_setup_nameplate_height()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = VillagerAIBehavior.new()


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
	return "NPC_NAME_VILLAGER"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) 


func _is_eligible_for_quest(quest_id: String) -> bool:
	return quest_id == "lost_bazaar" or quest_id == "bazaar_return"


func _has_ui_decorations() -> bool:
	return true


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(37, 1)


func interact(player_node: CharacterBody3D) -> void:
	var active_q := QuestService.get_active_quest()
	if active_q != null and active_q.quest_id == "lost_bazaar":
		_complete_starter_quest(player_node)
	else:
		_open_procedural_dialogue(player_node)


func _complete_starter_quest(player_node: CharacterBody3D) -> void:
	QuestService.complete_active_quest(player_node)
	
	var complete_node := DialogueNode.new()
	complete_node.node_id = "villager_quest_complete"
	complete_node.text = "DIALOGUE_VILLAGER_QUEST_COMPLETE"
	DialogueService.register_node(complete_node)
	
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		hud.open_dialogue(complete_node, "NPC_NAME_VILLAGER", self)


func _open_procedural_dialogue(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "villager_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
		hud.open_dialogue(intro_node, "NPC_NAME_VILLAGER", self)


func _select_procedural_greeting_key() -> String:
	if CelestialService.is_night_time_static():
		return "DIALOGUE_VILLAGER_NIGHT"
		
	var biome_id := BiomeService.get_biome_id_at_position(global_position, get_parent())
	match biome_id:
		0: return "DIALOGUE_VILLAGER_OCEAN"     
		4: return "DIALOGUE_VILLAGER_GLACIERS"   
		7: return "DIALOGUE_VILLAGER_NEON"        
		8: return "DIALOGUE_VILLAGER_SWAMP"       
		9: return "DIALOGUE_VILLAGER_CLOUD"       
		_:
			var variety_index := npc_seed % 3
			if variety_index == 0: return "DIALOGUE_VILLAGER_PLAINS_A"
			elif variety_index == 1: return "DIALOGUE_VILLAGER_PLAINS_B"
			return "DIALOGUE_VILLAGER_PLAINS_C"
