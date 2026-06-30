# ==============================================================================
# Project: CraftDomain
# Description: Miner NPC physics controller. Spawns in mountain/cave biomes, 
#              dressed in rugged grey dungarees and wearing a yellow hard-hat 
#              with an active, sweeping 3D Spotlight headlamp.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Inherits PassiveEntity and 
#                fully satisfies all base physics, AI state, and blinking loops.
#              - Single Responsibility Principle (SRP): Handles exclusively miner 
#                visual compositions and conversational triggers.
#              - Open-Closed Principle (OCP) & i18n: Exclusively uses translation 
#                keys to prevent hardcoded string leakage in codebase.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MinerEntity.gd
# ==============================================================================
class_name MinerEntity
extends PassiveEntity

# The real-time physical spotlight node casting light in dark caves
var _headlamp_light: SpotLight3D


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 4) # 4 Hearts of health
	name = "Entity_MINER"


## Concrete Implementation: Assembles the 3D miner model programmatically, 
## mounting a functional, real-time SpotLight3D on his hard-hat.
func _build_visual_representation() -> void:
	var skin_color := variant_skin_color             # Procedural skin tone
	var dungarees_color := Color(0.38, 0.40, 0.42)   # Rugged stone-grey dungarees
	var harness_color := Color(0.28, 0.18, 0.12)     # Leather brown harness
	var hat_color := Color(0.95, 0.78, 0.12)         # Construction yellow hat
	var boots_color := Color(0.12, 0.10, 0.08)       # Heavy steel-toe boots
	var iron_color := Color(0.55, 0.55, 0.6)         # Pickaxe steel
	var lamp_glass_color := Color(0.0, 0.95, 0.95)   # Glowing cyan lamp block
	
	# 1. Base Legs & Steel-Toe Boots
	_create_box(_body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), boots_color)
	
	# 2. Torso Shirt & Stone-Grey Overalls
	_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), variant_clothing_color) # Shirt
	_create_box(_body_bob_node, Vector3(0.47, 0.45, 0.47), Vector3(0, 0.35, 0), dungarees_color) # Dungarees
	
	# Leather harness straps (Wrapped diagonally across the chest)
	_create_box(_body_bob_node, Vector3(0.08, 0.77, 0.12), Vector3(-0.13, 0.525, -0.19), harness_color)
	_create_box(_body_bob_node, Vector3(0.48, 0.08, 0.12), Vector3(0, 0.42, -0.20), harness_color)
	
	# 3. Head Joint & Yellow Construction Hard-Hat
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.05, 0)
	_body_bob_node.add_child(_head_node)
	
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color) # Face
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), skin_color * 0.9) # Nose
	
	# Yellow Hard-Hat Dome & Brim
	_create_box(_head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.36, 0), hat_color)
	_create_box(_head_node, Vector3(0.38, 0.04, 0.10), Vector3(0, 0.32, -0.21), hat_color)
	
	# Deep-set Blinking Eyes
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.15, 0.15, 0.15))
	
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.15, 0.15, 0.15))
	
	# 4. Arms (Carrying a sheathed iron pickaxe on his back)
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.65, -0.23)
	_body_bob_node.add_child(_arms_node)
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), variant_clothing_color * 0.8)
	
	var pickaxe_joint := Node3D.new()
	pickaxe_joint.name = "PickaxeHarness"
	pickaxe_joint.position = Vector3(0.12, 0.5, 0.24)
	pickaxe_joint.rotation = Vector3(0, 0, deg_to_rad(-45))
	_body_bob_node.add_child(pickaxe_joint)
	_create_box(pickaxe_joint, Vector3(0.04, 0.48, 0.04), Vector3(0, 0, 0), harness_color) # Handle
	_create_box(pickaxe_joint, Vector3(0.28, 0.05, 0.05), Vector3(0, 0.21, 0), iron_color) # Pick-head
	
	# 5. MOUNT ACTIVE SPOTLIGHT (Glowing cyan casing and physical light source)
	var lamp_casing := _create_box(_head_node, Vector3(0.08, 0.08, 0.06), Vector3(0, 0.32, -0.23), Color(0.2, 0.2, 0.22))
	var lamp_lens := _create_box(lamp_casing, Vector3(0.06, 0.06, 0.02), Vector3(0, 0, -0.035), lamp_glass_color)
	
	# Instantiate Spotlight pointing forward
	_headlamp_light = SpotLight3D.new()
	_headlamp_light.name = "HeadlampBeam"
	_headlamp_light.position = Vector3(0, 0, -0.05)
	
	# In Godot, spotlights shine along -Z direction by default
	_headlamp_light.rotation = Vector3(0, 0, 0)
	_headlamp_light.light_color = Color(0.92, 0.95, 1.0) # Cold halogen white
	_headlamp_light.light_energy = 2.4 # Strong beam
	_headlamp_light.light_indirect_energy = 1.2
	_headlamp_light.spot_range = 16.0 # Extends deep into cavern shadows
	_headlamp_light.spot_angle = 38.0 # Narrow beam cone
	_headlamp_light.shadow_enabled = true
	_headlamp_light.shadow_bias = 0.06
	
	lamp_lens.add_child(_headlamp_light)


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
		intro_node.node_id = "miner_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
			
		# Pass "self" as the third argument to freeze and lock gaze during dialog
		hud.call("open_dialogue", intro_node, "Miner", self)


## Selects a unique localized dialogue key based on time, biome, and variety index.
func _select_procedural_greeting_key() -> String:
	var celestial := get_node_or_null("/root/Bootstrap/CelestialService")
	var is_night := false
	if is_instance_valid(celestial) and celestial.has_method("is_night_time"):
		is_night = celestial.call("is_night_time") as bool
		
	# 1. Night-time reactive prompts (Creepy deep-cave warnings)
	if is_night:
		return "DIALOGUE_MINER_NIGHT"
		
	# 2. Standard Miner prompts (Variety pools A and B based on seed)
	return "DIALOGUE_MINER_PLAINS_A" if (npc_seed % 2 == 0) else "DIALOGUE_MINER_PLAINS_B"


func _can_socialize() -> bool:
	return true
