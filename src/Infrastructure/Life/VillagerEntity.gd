# ==============================================================================
# Project: CraftDomain
# Description: Villager NPC entity. Inherits from the abstract base class PassiveEntity.
#              OCP COMPLIANT: Completely isolated from other NPC files.
#              UPDATED: Cleaned up quest triggers (SOLID OCP). Removed the hardcoded
#              set_active_quest("fuel_fryer") call to let the dynamic JSON-driven
#              campaign.json chain load the story campaign autonomously.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/VillagerEntity.gd
# ==============================================================================
class_name VillagerEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1)
	name = "Entity_VILLAGER"

func _build_visual_representation() -> void:
	var robe_color := Color(0.35, 0.22, 0.15)
	var apron_color := Color(0.25, 0.15, 0.1)
	
	# 1. Torso Robe
	_create_box(_visual_root, Vector3(0.45, 0.9, 0.45), Vector3(0, 0.55, 0), robe_color)
	
	# 2. Head Node
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.25, 0)
	_visual_root.add_child(_head_node)
	
	# Head skin
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.05, 0), Color(0.95, 0.75, 0.65))
	
	# Programmatic 3D Nose
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, -0.01, -0.21), Color(0.85, 0.65, 0.55))
	
	# Blinking Eyes
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.06, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.06, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	
	# 3. Folded arms
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.75, -0.21)
	_visual_root.add_child(_arms_node)
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), apron_color)

func _get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.61, 0.575)

func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.805, 0)

func _setup_floating_bubble() -> void:
	var sb_script: Script = load("res://src/Infrastructure/UI/SpeechBubble.gd")
	if sb_script != null:
		var bubble = sb_script.new() as Node3D
		add_child(bubble)
		bubble.call("set_text", "VILLAGER")

## Trigger custom dialogue and handle quest progression
func interact(player_node: CharacterBody3D) -> void:
	var active_q := QuestService.get_active_quest()
	
	# --- CAMPAIGN MISSION 1 TRIGGER: Talk to the Villager ---
	if active_q != null and active_q.quest_id == "lost_bazaar":
		# SOLID OCP FIX: We only call complete_active_quest passing the player node.
		# The QuestService will automatically grant rewards and chain-load the next
		# quest defined in your JSON, without any hardcoded scripts!
		QuestService.complete_active_quest(player_node)
		
		# Create story completion dialogue dynamically
		var complete_node := DialogueNode.new()
		complete_node.node_id = "villager_quest_complete"
		complete_node.text = "Thank goodness you found our bazaar, traveler! We were worried you were lost in the ocean bay. Here are some Wood Blocks to help you build a shelter.\n\nPlease check your mission tracker, you need to collect leaves to build a thatched roof!"
		DialogueService.register_node(complete_node)
		
		var hud = player_node.get("hud")
		if is_instance_valid(hud):
			hud.call("open_dialogue", complete_node, "Villager")
	else:
		# Standard fallback dialogue
		var hud = player_node.get("hud")
		if is_instance_valid(hud):
			var intro_node: Resource = DialogueService.get_dialogue_node("villager_intro")
			if intro_node == null:
				var fallback_node := DialogueNode.new()
				fallback_node.node_id = "villager_intro"
				fallback_node.text = "Hello, traveler! The Golden Bazaar plains are peaceful today. But be very careful if you explore the deep mountain caves at night!"
				DialogueService.register_node(fallback_node)
				intro_node = fallback_node
			hud.call("open_dialogue", intro_node, "Villager")

func _can_socialize() -> bool:
	return true
