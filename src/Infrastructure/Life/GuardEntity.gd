# ==============================================================================
# Project: CraftDomain
# Description: Guard NPC entity. Inherits from the abstract base class PassiveEntity.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Only manages guard behaviors,
#                combat stats, and guard aesthetics.
#              - Liskov Substitution Principle (LSP): Fully compatible base subclass.
#              MODEL UPGRADE: Complete heavy-soldier overhaul. Modeled metallic pauldrons,
#              iron-plated combat boots, an advanced military helmet with a nose-guard,
#              and a dual-sheathed iron sword + knightly heater shield on his back.
#              Fully rigged to `_body_bob_node` for solid footsteps physics.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GuardEntity.gd
# ==============================================================================
class_name GuardEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 3)
	name = "Entity_GUARD"

## Override: Assembles the 3D steel-plated soldier model programmatically
func _build_visual_representation() -> void:
	var armor_color := Color(0.40, 0.40, 0.45)       # Main steel plates color
	var sash_color := Color(0.65, 0.1, 0.1)          # Crimson red belt/sash
	var skin_color := Color(0.95, 0.75, 0.65)        # Skin
	var nose_color := Color(0.85, 0.65, 0.55)        # Nose
	var iron_color := Color(0.55, 0.55, 0.6)         # Lighter iron
	var gold_trim := Color(0.85, 0.6, 0.15)          # Gold accents
	var wood_color := Color(0.45, 0.3, 0.15)         # Shield wood backing
	
	# 1. Base Legs / Iron Greaves (Attached to the bouncing bob node!)
	_create_box(_body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), armor_color)
	
	# 2. Torso Steel Breastplate
	_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), armor_color)
	
	# Pauldrons: Bulkier 3D Shoulder armor plates (gives broad shoulders)
	_create_box(_body_bob_node, Vector3(0.12, 0.22, 0.35), Vector3(-0.25, 0.75, 0), iron_color) # Left pauldron
	_create_box(_body_bob_node, Vector3(0.12, 0.22, 0.35), Vector3(0.25, 0.75, 0), iron_color)  # Right pauldron
	
	# Crimson Belt
	_create_box(_body_bob_node, Vector3(0.48, 0.08, 0.48), Vector3(0, 0.45, 0), sash_color)
	
	# 3. Head Node & Advanced Helmet
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.05, 0)
	_body_bob_node.add_child(_head_node)
	
	# Skin head
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color)
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), nose_color)
	
	# Steel Helmet base
	_create_box(_head_node, Vector3(0.38, 0.22, 0.38), Vector3(0, 0.28, 0), iron_color)
	# Helmet Nose/Face Guard (Visor)
	_create_box(_head_node, Vector3(0.05, 0.18, 0.04), Vector3(0, 0.19, -0.20), iron_color)
	
	# Red Feather Plume on top
	_create_box(_head_node, Vector3(0.04, 0.24, 0.14), Vector3(0, 0.45, 0.05), sash_color) 
	
	# Blinking Soldier Eyes
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.15, 0.15, 0.15))
	
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.15, 0.15, 0.15))
	
	# 4. Arms (Red sleeves)
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.65, -0.23)
	_body_bob_node.add_child(_arms_node)
	
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), sash_color)
	
	# 5. Weaponry on Back
	# A. Sheathed Iron Sword
	var sword_joint := Node3D.new()
	sword_joint.name = "IronSwordJoint"
	sword_joint.position = Vector3(-0.2, 0.5, 0.24)
	sword_joint.rotation = Vector3(0, 0, deg_to_rad(-135)) 
	_body_bob_node.add_child(sword_joint)
	
	_create_box(sword_joint, Vector3(0.05, 0.45, 0.02), Vector3(0, 0.18, 0), iron_color)  # Blade
	_create_box(sword_joint, Vector3(0.15, 0.04, 0.04), Vector3(0, -0.04, 0), gold_trim)   # Guard
	_create_box(sword_joint, Vector3(0.04, 0.12, 0.04), Vector3(0, -0.1, 0), wood_color)   # Grip
	
	# B. Knightly Heater Shield (Mounted alongside the sword)
	var shield_joint := Node3D.new()
	shield_joint.name = "ShieldJoint"
	shield_joint.position = Vector3(0.1, 0.5, 0.25)
	shield_joint.rotation = Vector3(0, deg_to_rad(15), deg_to_rad(10))
	_body_bob_node.add_child(shield_joint)
	
	# Wooden board
	_create_box(shield_joint, Vector3(0.35, 0.5, 0.05), Vector3(0, 0, 0), wood_color)
	# Steel trim borders
	_create_box(shield_joint, Vector3(0.39, 0.04, 0.07), Vector3(0, 0.24, 0.01), iron_color) # Top rim
	_create_box(shield_joint, Vector3(0.04, 0.52, 0.07), Vector3(-0.18, -0.01, 0.01), iron_color) # Left rim
	_create_box(shield_joint, Vector3(0.04, 0.52, 0.07), Vector3(0.18, -0.01, 0.01), iron_color)  # Right rim
	# Heraldic Crimson Crest (Center pattern)
	_create_box(shield_joint, Vector3(0.12, 0.32, 0.08), Vector3(0, 0, 0.01), sash_color)

func _get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.5, 0.575)

func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.75, 0)

func _setup_floating_bubble() -> void:
	var sb_script: Script = load("res://src/Infrastructure/UI/SpeechBubble.gd")
	if sb_script != null:
		var bubble = sb_script.new() as Node3D
		add_child(bubble)
		bubble.call("set_text", "GUARD")

func interact(player_node: CharacterBody3D) -> void:
	var hud = player_node.get("hud")
	if is_instance_valid(hud):
		var intro_node: Resource = DialogueService.get_dialogue_node("guard_intro")
		if intro_node == null:
			var fallback_node := DialogueNode.new()
			fallback_node.node_id = "guard_intro"
			fallback_node.text = "Hail, traveler! I stand watch over this village bazaar. Rest easy; my steel blade will keep the cave zombies at bay!"
			DialogueService.register_node(fallback_node)
			intro_node = fallback_node
			
		hud.call("open_dialogue", intro_node, "Guard")

func _select_next_random_task() -> void:
	var roll := randf()
	if roll < 0.65:
		current_task = TaskState.WANDERING 
		var angle := randf() * TAU
		_wander_direction = Vector3(cos(angle), 0, sin(angle))
		_task_timer = randf_range(4.0, 9.0)
	else:
		current_task = TaskState.IDLE 
		_task_timer = randf_range(2.0, 5.0)

func _can_socialize() -> bool:
	return true
