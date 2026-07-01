# ==============================================================================
# Project: CraftDomain
# Description: Druid NPC physics controller. Spawns in forest/canopy biomes,
#              dressed in moss-green robes with leather harnesses, wearing a 
#              golden leaf crown, and carrying a carved wooden bow.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Inherits PassiveEntity.
#              - Single Responsibility Principle (SRP): Delegates rendering setups 
#                and AI state execution to specialized sibling components.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/DruidEntity.gd
# ==============================================================================
class_name DruidEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 4) # 4 Hearts of health
	name = "Entity_DRUID"


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	# Extract procedural color parameters calculated on boot by the visual component
	var skin_color: Color = visual_component.variant_skin_color             # Procedural skin tone
	var hair_color: Color = visual_component.variant_hair_color             # Procedural hair color
	
	# Fallback accessory colors
	var robe_color := Color(0.18, 0.45, 0.15)        # Mossy forest-green robes
	var harness_color := Color(0.35, 0.22, 0.15)     # Dark leather straps
	var gold_trim := Color(0.85, 0.6, 0.15)          # Golden leaf crowns
	var boots_color := Color(0.15, 0.1, 0.08)        # Dark leather boots
	var wood_color := Color(0.48, 0.35, 0.22)        # Bow wood
	
	# 1. Base Legs & Feet (Attached to the bobbing joint of visual component)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), boots_color)
	
	# 2. Clothed Torso Tunic & Overlap Sashes
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), robe_color)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.08, 0.47), Vector3(0, 0.45, 0), harness_color) # Belt
	
	# Diagonal shoulder harness strap (for mounting the bow)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.08, 0.77, 0.12), Vector3(-0.13, 0.525, -0.19), harness_color)
	
	# 3. Head Joint Setup
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "HumanHead"
	visual_component.head_node.position = Vector3(0, 1.05, 0)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	visual_component.create_box(visual_component.head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color) # Face
	visual_component.create_box(visual_component.head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), skin_color * 0.9) # Nose
	
	# Procedural Hair Plates
	visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.18, 0.38), Vector3(0, 0.30, 0.03), hair_color)
	
	# Golden Leaf Crown
	visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.04, 0.38), Vector3(0, 0.28, 0), gold_trim)
	visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.12, 0.04), Vector3(0, 0.34, -0.18), Color(0.25, 0.65, 0.18)) # Leaf accent
	
	# Blinking Eyes (Warm brown pupils, assigned to visual component tracking)
	visual_component.left_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	visual_component.create_box(visual_component.left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.3, 0.2, 0.1))
	
	visual_component.right_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	visual_component.create_box(visual_component.right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.3, 0.2, 0.1))
	
	# 4. Arms Folded
	visual_component.arms_node = Node3D.new()
	visual_component.arms_node.name = "ArmsJoint"
	visual_component.arms_node.position = Vector3(0, 0.65, -0.23)
	visual_component.body_bob_node.add_child(visual_component.arms_node)
	visual_component.create_box(visual_component.arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), robe_color * 0.8)
	
	# 5. Weaponry: Stored Wooden Bow on Back (Attached to the bouncing joint of visual component)
	var bow_joint := Node3D.new()
	bow_joint.name = "WoodenBowHarness"
	bow_joint.position = Vector3(0.15, 0.5, 0.24)
	bow_joint.rotation = Vector3(0, 0, deg_to_rad(35))
	visual_component.body_bob_node.add_child(bow_joint)
	
	# Curved segments representing bow limbs
	visual_component.create_box(bow_joint, Vector3(0.04, 0.48, 0.04), Vector3(0, 0, 0), wood_color) # Center limb
	visual_component.create_box(bow_joint, Vector3(0.04, 0.12, 0.08), Vector3(0, 0.24, -0.04), wood_color) # Top curve
	visual_component.create_box(bow_joint, Vector3(0.04, 0.12, 0.08), Vector3(0, -0.24, -0.04), wood_color) # Bottom curve
	visual_component.create_box(bow_joint, Vector3(0.01, 0.54, 0.01), Vector3(0, 0, -0.06), Color(0.85, 0.85, 0.90)) # Bow string


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
		intro_node.node_id = "druid_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
			
		hud.open_dialogue(intro_node, "Druid", self)


## Selects a unique localized dialogue key based on time, biome, and variety index.
func _select_procedural_greeting_key() -> String:
	var celestial := get_node_or_null("/root/Bootstrap/CelestialService")
	var is_night := false
	if is_instance_valid(celestial) and celestial.has_method("is_night_time"):
		is_night = celestial.call("is_night_time") as bool
		
	if is_night:
		return "DIALOGUE_DRUID_NIGHT"
		
	return "DIALOGUE_DRUID_PLAINS_A" if (npc_seed % 2 == 0) else "DIALOGUE_DRUID_PLAINS_B"


func _can_socialize() -> bool:
	return true
