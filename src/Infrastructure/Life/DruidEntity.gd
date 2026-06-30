# ==============================================================================
# Project: CraftDomain
# Description: Druid NPC physics controller. Spawns in forest/canopy biomes,
#              dressed in moss-green robes with leather harnesses, wearing a 
#              golden leaf crown, and carrying a carved wooden bow.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Inherits PassiveEntity and 
#                fully satisfies all base physics, AI state, and blinking loops.
#              - Single Responsibility Principle (SRP): Handles exclusively druidic 
#                visual compositions and conversational triggers.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/DruidEntity.gd
# ==============================================================================
class_name DruidEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 4) # 4 Hearts of health
	name = "Entity_DRUID"


## Concrete Implementation: Assembles a detailed druid model programmatically, 
## mounting a sheathed wooden bow on their shoulder harness.
func _build_visual_representation() -> void:
	var skin_color := variant_skin_color             # Procedural skin tone
	var hair_color := variant_hair_color             # Procedural hair color
	var robe_color := Color(0.18, 0.45, 0.15)        # Mossy forest-green robes
	var harness_color := Color(0.35, 0.22, 0.15)     # Dark leather straps
	var gold_trim := Color(0.85, 0.6, 0.15)          # Golden leaf crowns
	var boots_color := Color(0.15, 0.1, 0.08)        # Dark leather boots
	var wood_color := Color(0.48, 0.35, 0.22)        # Bow wood
	
	# 1. Base Legs & Feet
	_create_box(_body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), boots_color)
	
	# 2. Clothed Torso Tunic & Overlap Sashes
	_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), robe_color)
	_create_box(_body_bob_node, Vector3(0.47, 0.08, 0.47), Vector3(0, 0.45, 0), harness_color) # Belt
	
	# Diagonal shoulder harness strap (for mounting the bow)
	_create_box(_body_bob_node, Vector3(0.08, 0.77, 0.12), Vector3(-0.13, 0.525, -0.19), harness_color)
	
	# 3. Head Joint & Golden Leaf Crown
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.05, 0)
	_body_bob_node.add_child(_head_node)
	
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color) # Face
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), skin_color * 0.9) # Nose
	
	# Procedural Hair Plates
	_create_box(_head_node, Vector3(0.38, 0.18, 0.38), Vector3(0, 0.30, 0.03), hair_color)
	
	# Golden Leaf Crown
	_create_box(_head_node, Vector3(0.38, 0.04, 0.38), Vector3(0, 0.28, 0), gold_trim)
	_create_box(_head_node, Vector3(0.08, 0.12, 0.04), Vector3(0, 0.34, -0.18), Color(0.25, 0.65, 0.18)) # Leaf accent
	
	# Blinking Eyes (Warm brown pupils)
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.3, 0.2, 0.1))
	
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.3, 0.2, 0.1))
	
	# 4. Arms Folded
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.65, -0.23)
	_body_bob_node.add_child(_arms_node)
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), robe_color * 0.8)
	
	# 5. Weaponry: Stored Wooden Bow on Back
	var bow_joint := Node3D.new()
	bow_joint.name = "WoodenBowHarness"
	bow_joint.position = Vector3(0.15, 0.5, 0.24)
	bow_joint.rotation = Vector3(0, 0, deg_to_rad(35))
	_body_bob_node.add_child(bow_joint)
	
	# Curved curved segments representing bow limbs
	_create_box(bow_joint, Vector3(0.04, 0.48, 0.04), Vector3(0, 0, 0), wood_color) # Center limb
	_create_box(bow_joint, Vector3(0.04, 0.12, 0.08), Vector3(0, 0.24, -0.04), wood_color) # Top curve
	_create_box(bow_joint, Vector3(0.04, 0.12, 0.08), Vector3(0, -0.24, -0.04), wood_color) # Bottom curve
	_create_box(bow_joint, Vector3(0.01, 0.54, 0.01), Vector3(0, 0, -0.06), Color(0.85, 0.85, 0.90)) # Bow string


func _get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.5, 0.575)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.75, 0)


func _setup_floating_bubble() -> void:
	var sb_script: Script = load("res://src/Infrastructure/UI/SpeechBubble.gd")
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", "RIGHT-CLICK TO TALK!")


## Public Gaze Interaction: Localized dialogue trees.
func interact(player_node: CharacterBody3D) -> void:
	var hud = player_node.get("hud")
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "druid_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
			
		# Pass "self" as the third argument to freeze and lock gaze during dialog
		hud.call("open_dialogue", intro_node, "Druid", self)


## Selects a unique localized dialogue key based on time, biome, and variety index.
func _select_procedural_greeting_key() -> String:
	var celestial := get_node_or_null("/root/Bootstrap/CelestialService")
	var is_night := false
	if is_instance_valid(celestial) and celestial.has_method("is_night_time"):
		is_night = celestial.call("is_night_time") as bool
		
	# 1. Night-time reactive prompts (Alert of dark wood whispers)
	if is_night:
		return "DIALOGUE_DRUID_NIGHT"
		
	# 2. Standard Druid prompts (Variety pools A and B based on seed)
	return "DIALOGUE_DRUID_PLAINS_A" if (npc_seed % 2 == 0) else "DIALOGUE_DRUID_PLAINS_B"


func _can_socialize() -> bool:
	return true
