# ==============================================================================
# Project: CraftDomain
# Description: Merchant NPC entity. Inherits from the abstract base class PassiveEntity.
#              OCP COMPLIANT: Completely isolated from other NPC files.
#              UPDATED: Wired dynamic PBR texture mapping for the face (merchant_face.png)
#              and body (merchant_body.png) with smart solid-color PBR fallback.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MerchantEntity.gd
# ==============================================================================
class_name MerchantEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1)
	name = "Entity_MERCHANT"

func _build_visual_representation() -> void:
	var robe_color := Color(0.45, 0.15, 0.6)
	var apron_color := Color(0.85, 0.6, 0.15)
	
	# 1. Torso Robe (Loads merchant_body.png if exists)
	_create_box(_visual_root, Vector3(0.45, 0.9, 0.45), Vector3(0, 0.55, 0), robe_color, "merchant_body.png")
	
	# 2. Head Node
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.25, 0)
	_visual_root.add_child(_head_node)
	
	# Head skin (Loads merchant_face.png if exists)
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.05, 0), Color(0.95, 0.75, 0.65), "merchant_face.png")
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, -0.01, -0.21), Color(0.85, 0.65, 0.55))
	
	# Eyes
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.06, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.18, 0.42, 0.68))
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.06, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.18, 0.42, 0.68))
	
	# 3. Folded arms (apron)
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
		bubble.call("set_text", "MERCHANT")

func interact(player_node: CharacterBody3D) -> void:
	var hud = player_node.get("hud")
	if is_instance_valid(hud):
		var intro_node: Resource = DialogueService.get_dialogue_node("merchant_intro")
		if intro_node != null:
			hud.call("open_dialogue", intro_node, "Merchant")

func _can_socialize() -> bool:
	return true
