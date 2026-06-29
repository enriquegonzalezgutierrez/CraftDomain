# ==============================================================================
# Project: CraftDomain
# Description: Villager NPC entity. Inherits from the abstract base class PassiveEntity.
#              SOLID COMPLIANCE: Adheres to LSP by executing logic polymorphically.
#              MODEL UPGRADE: Upgraded from a simple 3-box design to a highly 
#              detailed voxel composition. Added leather boots, a distinct leather 
#              belt with an iron buckle, and attached all geometry to the new 
#              `_body_bob_node` so the entire character bounces naturally when walking.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/VillagerEntity.gd
# ==============================================================================
class_name VillagerEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1)
	name = "Entity_VILLAGER"

## Overrides: Assembles a detailed 3D human villager model
func _build_visual_representation() -> void:
	var robe_color := Color(0.35, 0.22, 0.15)       # Main brown robe
	var skin_color := Color(0.95, 0.75, 0.65)       # Peachy skin
	var nose_color := Color(0.85, 0.65, 0.55)       # Slightly darker nose
	var belt_color := Color(0.18, 0.12, 0.08)       # Dark leather
	var buckle_color := Color(0.65, 0.65, 0.7)      # Iron grey
	var boots_color := Color(0.15, 0.1, 0.08)       # Very dark brown
	var folded_arms_color := Color(0.25, 0.15, 0.1) # Slightly darker sleeve color
	
	# 1. Base Legs / Boots (Attached to the bouncing bob node!)
	_create_box(_body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), boots_color)
	
	# 2. Main Torso Robe
	_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), robe_color)
	
	# 3. Leather Belt & Iron Buckle (Wrapped around waist)
	_create_box(_body_bob_node, Vector3(0.48, 0.08, 0.48), Vector3(0, 0.45, 0), belt_color)
	_create_box(_body_bob_node, Vector3(0.12, 0.1, 0.05), Vector3(0, 0.45, -0.25), buckle_color)
	
	# 4. Head Node & Face details
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.05, 0) # Positioned right above the torso
	_body_bob_node.add_child(_head_node)
	
	# Head cube
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color)
	
	# Prominent 3D Voxel Nose
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), nose_color)
	
	# Deep-set Blinking Eyes
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2)) # Dark pupil
	
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	
	# 5. Folded Arms (Classic Minecraft NPC stance)
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.65, -0.23) # Rest on the chest
	_body_bob_node.add_child(_arms_node)
	
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), folded_arms_color)

func _get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.5, 0.575)

func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.75, 0)

func _setup_floating_bubble() -> void:
	var sb_script: Script = load("res://src/Infrastructure/UI/SpeechBubble.gd")
	if sb_script != null:
		_bubble = sb_script.new() as Node3D # Bind to parent class member
		add_child(_bubble)
		_bubble.call("set_text", "RIGHT-CLICK TO TALK!")

## Trigger custom dialogue and handle quest progression
func interact(player_node: CharacterBody3D) -> void:
	var active_q := QuestService.get_active_quest()
	
	if active_q != null and active_q.quest_id == "lost_bazaar":
		QuestService.complete_active_quest(player_node)
		
		var complete_node := DialogueNode.new()
		complete_node.node_id = "villager_quest_complete"
		complete_node.text = "Thank goodness you found our bazaar, traveler! We were worried you were lost in the ocean bay. Here are some Wood Blocks to help you build a shelter.\n\nPlease check your mission tracker, you need to collect leaves to build a thatched roof!"
		DialogueService.register_node(complete_node)
		
		var hud = player_node.get("hud")
		if is_instance_valid(hud):
			hud.call("open_dialogue", complete_node, "Villager")
	else:
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
