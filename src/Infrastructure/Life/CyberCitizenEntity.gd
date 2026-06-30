# ==============================================================================
# Project: CraftDomain
# Description: Cyber Citizen NPC physics controller. Spawns in Neon Ruins, 
#              built out of dark obsidian-steel metallic boxes, detailed with 
#              glowing cyan visor bands and magenta circuitry pipelines.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Inherits PassiveEntity and 
#                fully satisfies all base physics, AI state, and blinking loops.
#              - Single Responsibility Principle (SRP): Handles exclusively cybernetic 
#                visual compositions and conversational triggers.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/CyberCitizenEntity.gd
# ==============================================================================
class_name CyberCitizenEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 5) # 5 Hearts of health (10 HP)
	name = "Entity_CYBER"


## Concrete Implementation: Assembles a futuristic android chassis, 
## detailed with glowing neon pathways and visors.
func _build_visual_representation() -> void:
	var steel_color := Color(0.12, 0.12, 0.14)      # Dark matte obsidian-steel
	var chrome_color := Color(0.35, 0.35, 0.38)     # Raw aluminum
	var neon_cyan := Color(0.0, 0.95, 0.95)         # Glowing cyan circuit
	var neon_magenta := Color(0.95, 0.0, 0.95)      # Glowing magenta visor
	
	# 1. Base Legs & Metallic Chrome Feet
	_create_box(_body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), chrome_color)
	_create_box(_body_bob_node, Vector3(0.15, 0.45, 0.15), Vector3(-0.1, 0.3, 0), steel_color) # Left leg
	_create_box(_body_bob_node, Vector3(0.15, 0.45, 0.15), Vector3(0.1, 0.3, 0), steel_color)  # Right leg
	
	# 2. Torso Carbon Breastplate & Cyber Sashes
	_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), steel_color)
	
	# Cyan power core in the center of chest
	_create_box(_body_bob_node, Vector3(0.12, 0.12, 0.05), Vector3(0, 0.65, -0.23), neon_cyan)
	# Lateral neon pipeline channels
	_create_box(_body_bob_node, Vector3(0.47, 0.06, 0.47), Vector3(0, 0.48, 0), neon_magenta)
	_create_box(_body_bob_node, Vector3(0.47, 0.06, 0.47), Vector3(0, 0.32, 0), neon_cyan)
	
	# 3. Head Joint & Sleek Cyan Visor Dome
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.05, 0)
	_body_bob_node.add_child(_head_node)
	
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), steel_color) # Face
	
	# Sleek glowing cyan horizontal visor plate (Covers standard blinking eyes)
	_create_box(_head_node, Vector3(0.38, 0.10, 0.08), Vector3(0, 0.19, -0.16), neon_cyan)
	# Top head-antenna
	_create_box(_head_node, Vector3(0.04, 0.18, 0.04), Vector3(0, 0.46, 0), chrome_color)
	_create_box(_head_node, Vector3(0.06, 0.06, 0.06), Vector3(0, 0.54, 0), neon_magenta) # Antenna tip
	
	# 4. Arms (Equipped with glowing magenta circuitry sleeves)
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.65, -0.23)
	_body_bob_node.add_child(_arms_node)
	
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), steel_color)
	# Cyan wristbands
	_create_box(_arms_node, Vector3(0.60, 0.04, 0.25), Vector3(0, 0, 0), neon_magenta)


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
		intro_node.node_id = "cyber_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
			
		# Pass "self" as the third argument to freeze and lock gaze during dialog
		hud.call("open_dialogue", intro_node, "Android", self)


## Selects a unique localized dialogue key based on time, biome, and variety index.
func _select_procedural_greeting_key() -> String:
	var celestial := get_node_or_null("/root/Bootstrap/CelestialService")
	var is_night := false
	if is_instance_valid(celestial) and celestial.has_method("is_night_time"):
		is_night = celestial.call("is_night_time") as bool
		
	# 1. Night-time reactive prompts (Cyber grids alert)
	if is_night:
		return "DIALOGUE_CYBER_NIGHT"
		
	# 2. Standard Cyber prompts (Variety pools A and B based on seed)
	return "DIALOGUE_CYBER_PLAINS_A" if (npc_seed % 2 == 0) else "DIALOGUE_CYBER_PLAINS_B"


func _can_socialize() -> bool:
	return true
