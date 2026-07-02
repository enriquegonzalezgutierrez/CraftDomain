# ==============================================================================
# Project: CraftDomain
# Description: Miner NPC physics controller. Spawns in mountain/cave biomes, 
#              dressed in rugged grey dungarees and wearing a yellow hard-hat 
#              with an active, sweeping 3D Spotlight headlamp.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Inherits PassiveEntity.
#              - Single Responsibility Principle (SRP): Delegates rendering setups 
#                and AI state execution to specialized sibling components.
#              BUG FIX (i18n): Replaced hardcoded name string with localized 
#              translation keys to maintain strict multi-language support.
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


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	# Extract procedural color parameters calculated on boot by the visual component
	var skin_color: Color = visual_component.variant_skin_color             # Procedural skin tone
	var shirt_color: Color = visual_component.variant_clothing_color        # Procedural shirt
	
	# Fallback accessory colors
	var dungarees_color := Color(0.38, 0.40, 0.42)   # Rugged stone-grey dungarees
	var harness_color := Color(0.28, 0.18, 0.12)     # Leather brown harness
	var hat_color := Color(0.95, 0.78, 0.12)         # Construction yellow hat
	var boots_color := Color(0.12, 0.10, 0.08)       # Heavy steel-toe boots
	var iron_color := Color(0.55, 0.55, 0.6)         # Pickaxe steel
	var lamp_glass_color := Color(0.0, 0.95, 0.95)   # Glowing cyan lamp block
	
	# 1. Base Legs & Steel-Toe Boots (Attached to the bobbing joint of visual component)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), boots_color)
	
	# 2. Torso Shirt & Stone-Grey Overalls
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), shirt_color) # Shirt
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.45, 0.47), Vector3(0, 0.35, 0), dungarees_color) # Dungarees
	
	# Leather harness straps (Wrapped diagonally across the chest)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.08, 0.77, 0.12), Vector3(-0.13, 0.525, -0.19), harness_color)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.48, 0.08, 0.12), Vector3(0, 0.42, -0.20), harness_color)
	
	# 3. Head Joint Setup
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "HumanHead"
	visual_component.head_node.position = Vector3(0, 1.05, 0)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	visual_component.create_box(visual_component.head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color) # Face
	visual_component.create_box(visual_component.head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), skin_color * 0.9) # Nose
	
	# Yellow Hard-Hat Dome & Brim
	visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.36, 0), hat_color)
	visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.04, 0.10), Vector3(0, 0.32, -0.21), hat_color)
	
	# Deep-set Blinking Eyes (Assigned to visual component tracking)
	visual_component.left_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	visual_component.create_box(visual_component.left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.15, 0.15, 0.15))
	
	visual_component.right_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	visual_component.create_box(visual_component.right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.15, 0.15, 0.15))
	
	# 4. Arms
	visual_component.arms_node = Node3D.new()
	visual_component.arms_node.name = "ArmsJoint"
	visual_component.arms_node.position = Vector3(0, 0.65, -0.23)
	visual_component.body_bob_node.add_child(visual_component.arms_node)
	visual_component.create_box(visual_component.arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), shirt_color * 0.8)
	
	# Stored iron pickaxe on back
	var pickaxe_joint := Node3D.new()
	pickaxe_joint.name = "PickaxeHarness"
	pickaxe_joint.position = Vector3(0.12, 0.5, 0.24)
	pickaxe_joint.rotation = Vector3(0, 0, deg_to_rad(-45))
	visual_component.body_bob_node.add_child(pickaxe_joint)
	visual_component.create_box(pickaxe_joint, Vector3(0.04, 0.48, 0.04), Vector3(0, 0, 0), harness_color) # Handle
	visual_component.create_box(pickaxe_joint, Vector3(0.28, 0.05, 0.05), Vector3(0, 0.21, 0), iron_color) # Pick-head
	
	# 5. MOUNT ACTIVE SPOTLIGHT (Casing attached to the head node so light moves with the head!)
	var lamp_casing := visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.06), Vector3(0, 0.32, -0.23), Color(0.2, 0.2, 0.22))
	var lamp_lens := visual_component.create_box(lamp_casing, Vector3(0.06, 0.06, 0.02), Vector3(0, 0, -0.035), lamp_glass_color)
	
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
		intro_node.node_id = "miner_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
			
		hud.open_dialogue(intro_node, "NPC_NAME_MINER", self)


## Selects a unique localized dialogue key based on time, biome, and variety index.
func _select_procedural_greeting_key() -> String:
	var celestial := get_node_or_null("/root/Bootstrap/CelestialService")
	var is_night := false
	if is_instance_valid(celestial) and celestial.has_method("is_night_time"):
		is_night = celestial.call("is_night_time") as bool
		
	if is_night:
		return "DIALOGUE_MINER_NIGHT"
		
	return "DIALOGUE_MINER_PLAINS_A" if (npc_seed % 2 == 0) else "DIALOGUE_MINER_PLAINS_B"


func _can_socialize() -> bool:
	return true
