# ==============================================================================
# Project: CraftDomain
# Description: Merchant NPC entity. Inherits from the abstract base class PassiveEntity.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Isolates merchant-specific
#                trading triggers and visual properties.
#              - Liskov Substitution Principle (LSP): Fully compatible with 
#                the base PassiveEntity class.
#              UX UPGRADE: Added failsafe fallback dialogue node instantiation
#              so the Merchant never fails silently if database loads late.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MerchantEntity.gd
# ==============================================================================
class_name MerchantEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1)
	name = "Entity_MERCHANT"

## Overrides: Assembles a premium, highly detailed merchant model
func _build_visual_representation() -> void:
	var robe_color := Color(0.45, 0.15, 0.6)         # Royal violet túnica
	var skin_color := Color(0.95, 0.75, 0.65)         # Peachy skin
	var nose_color := Color(0.85, 0.65, 0.55)         # Nose
	var apron_color := Color(0.85, 0.6, 0.15)         # Golden yellow apron
	var boots_color := Color(0.15, 0.1, 0.08)         # Dark leather boots
	var turban_color := Color(0.9, 0.82, 0.45)        # Soft gold turban
	var emerald_color := Color(0.0, 0.85, 0.35)       # Glowing green gem
	
	_create_box(_body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), boots_color)
	_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), robe_color)
	_create_box(_body_bob_node, Vector3(0.3, 0.5, 0.05), Vector3(0, 0.38, -0.23), apron_color)
	
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.05, 0)
	_body_bob_node.add_child(_head_node)
	
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color)
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), nose_color)
	_create_box(_head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.36, 0), turban_color)
	_create_box(_head_node, Vector3(0.22, 0.08, 0.22), Vector3(0, 0.44, 0), turban_color)
	_create_box(_head_node, Vector3(0.06, 0.08, 0.04), Vector3(0, 0.36, -0.20), emerald_color)
	
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.18, 0.42, 0.68))
	
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.18, 0.42, 0.68))
	
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.65, -0.25)
	_body_bob_node.add_child(_arms_node)
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), apron_color)

func _get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.5, 0.575)

func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.75, 0)

func _setup_floating_bubble() -> void:
	var sb_script: Script = load("res://src/Infrastructure/UI/SpeechBubble.gd")
	if sb_script != null:
		_bubble = sb_script.new() as Node3D # Bind to parent class member
		add_child(_bubble)
		_bubble.call("set_text", "RIGHT-CLICK TO TRADE!")

## Public Interaction API: Restores dialogue interface safely with failsafe check
func interact(player_node: CharacterBody3D) -> void:
	var hud = player_node.get("hud")
	if is_instance_valid(hud):
		var intro_node: Resource = DialogueService.get_dialogue_node("merchant_intro")
		
		# FAILSAFE OVERLAY: If database loaded late, rebuild merchant tree on the fly!
		if intro_node == null:
			print("[MerchantEntity] Dialogue node was null! Initializing local fallback...")
			DialogueRegistry.initialize_dialogue_database()
			intro_node = DialogueService.get_dialogue_node("merchant_intro")
			
		if intro_node != null:
			hud.call("open_dialogue", intro_node, "Merchant")

func _can_socialize() -> bool:
	return true
