# ==============================================================================
# Project: CraftDomain
# Description: Cyber Citizen NPC physics controller. Spawns in Neon Ruins, 
#              built out of dark obsidian-steel metallic boxes, detailed with 
#              glowing cyan visor bands and magenta circuitry pipelines.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Inherits PassiveEntity.
#              - Single Responsibility Principle (SRP): Delegates rendering setups 
#                and AI state execution to specialized sibling components.
#              BUG FIX (i18n): Replaced hardcoded name string with localized 
#              translation keys to maintain strict multi-language support.
#              UX MODELING OVERHAUL (CLAY ANDROID):
#              - Upgraded visual boxes: added a dark carbon-obsidian chest armor, 
#                a highly detailed scanning visor covering the eyes, 
#                and glowing magenta and cyan micro-circuitry pipelines across 
#                his torso and wristbands.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/CyberCitizenEntity.gd
# ==============================================================================
class_name CyberCitizenEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 5) # 5 Hearts of health (10 HP)
	name = "Entity_CYBER"


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	var steel_color := Color(0.12, 0.12, 0.14)      # Dark matte obsidian-steel
	var chrome_color := Color(0.35, 0.35, 0.38)     # Raw aluminum chrome
	var neon_cyan := Color(0.0, 0.95, 0.95)         # Glowing cyan circuit
	var neon_magenta := Color(0.95, 0.0, 0.95)      # Glowing magenta visor
	
	# 1. Base Legs & Metallic Chrome Feet (Attached to the bouncing joint of visual component)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), chrome_color)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.15, 0.45, 0.15), Vector3(-0.1, 0.3, 0), steel_color) # Left leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.15, 0.45, 0.15), Vector3(0.1, 0.3, 0), steel_color)  # Right leg
	
	# 2. Torso Carbon Breastplate & Cyber Sashes
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), steel_color)
	
	# Cyan power core in the center of chest (With high emissive glow!)
	var power_core := visual_component.create_box(visual_component.body_bob_node, Vector3(0.12, 0.12, 0.05), Vector3(0, 0.65, -0.23), neon_cyan)
	var em_cyan := ORMMaterial3D.new()
	em_cyan.albedo_color = neon_cyan
	em_cyan.emission_enabled = true
	em_cyan.emission = Color(0.0, 1.0, 1.0)
	em_cyan.emission_energy_multiplier = 2.0
	power_core.material_override = em_cyan
	
	# Lateral neon pipeline channels
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.06, 0.47), Vector3(0, 0.48, 0), neon_magenta)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.06, 0.47), Vector3(0, 0.32, 0), neon_cyan)
	
	# 3. Head Joint Setup (Taller Cyber Forehead)
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "HumanHead"
	visual_component.head_node.position = Vector3(0, 1.05, 0)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	visual_component.create_box(visual_component.head_node, Vector3(0.35, 0.45, 0.35), Vector3(0, 0.225, 0), steel_color) # Face
	
	# Sleek glowing cyan horizontal visor plate (Covers standard blinking eyes, no eyes tracked here)
	var visor := visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.10, 0.08), Vector3(0, 0.22, -0.16), neon_cyan)
	visor.material_override = em_cyan
	
	# Top head-antenna
	visual_component.create_box(visual_component.head_node, Vector3(0.04, 0.18, 0.04), Vector3(0, 0.52, 0), chrome_color)
	
	var antenna_tip := visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.06, 0.06), Vector3(0, 0.60, 0), neon_magenta) # Antenna tip
	var em_magenta := ORMMaterial3D.new()
	em_magenta.albedo_color = neon_magenta
	em_magenta.emission_enabled = true
	em_magenta.emission = Color(1.0, 0.0, 1.0)
	em_magenta.emission_energy_multiplier = 2.0
	antenna_tip.material_override = em_magenta
	
	# 4. Arms folded setup
	visual_component.arms_node = Node3D.new()
	visual_component.arms_node.name = "ArmsJoint"
	visual_component.arms_node.position = Vector3(0, 0.65, -0.23)
	visual_component.body_bob_node.add_child(visual_component.arms_node)
	
	visual_component.create_box(visual_component.arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), steel_color)
	# Cyan wristbands
	visual_component.create_box(visual_component.arms_node, Vector3(0.60, 0.04, 0.25), Vector3(0, 0, 0), neon_magenta)


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
		intro_node.node_id = "cyber_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
			
		hud.open_dialogue(intro_node, "NPC_NAME_ANDROID", self)


## Selects a unique localized dialogue key based on time, biome, and variety index.
func _select_procedural_greeting_key() -> String:
	var celestial := get_node_or_null("/root/Bootstrap/CelestialService")
	var is_night := false
	if is_instance_valid(celestial) and celestial.has_method("is_night_time"):
		is_night = celestial.call("is_night_time") as bool
		
	if is_night:
		return "DIALOGUE_CYBER_NIGHT"
		
	return "DIALOGUE_CYBER_PLAINS_A" if (npc_seed % 2 == 0) else "DIALOGUE_CYBER_PLAINS_B"


func _can_socialize() -> bool:
	return true
