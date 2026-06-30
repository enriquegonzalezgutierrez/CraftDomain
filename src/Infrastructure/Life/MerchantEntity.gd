# ==============================================================================
# Project: CraftDomain
# Description: Merchant NPC physics controller. Generates highly customized 
#              clothes, aprons, and turbans based on its home biome coordinate.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Inherits PassiveEntity and 
#                fully satisfies all base physics, AI state, and blinking loops.
#              - Single Responsibility Principle (SRP): Handles exclusively merchant 
#                visual variations and dialog triggers.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MerchantEntity.gd
# ==============================================================================
class_name MerchantEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 3) # 3 Hearts of health
	name = "Entity_MERCHANT"


## Concrete Implementation: Assembles a detailed 3D model, applying unique 
## robes, sashes, aprons, and turbans based on the local biome sector.
func _build_visual_representation() -> void:
	var biome_id := _detect_current_biome()
	
	# Fallback Colors
	var skin_color := variant_skin_color
	var robe_color := Color(0.45, 0.15, 0.6)         # Royal violet robe
	var apron_color := Color(0.85, 0.6, 0.15)        # Golden yellow apron
	var sash_color := variant_clothing_color          # Procedural waist sash
	var boots_color := Color(0.15, 0.1, 0.08)        # Dark leather boots
	var turban_color := Color(0.9, 0.82, 0.45)       # Soft gold turban
	var jewel_color := Color(0.0, 0.85, 0.35)        # Glowing green emerald gem
	
	# Determine specialized colors based on biome
	match biome_id:
		0: # Bay of Sails (Sea-Rover Blue & Red)
			robe_color = Color(0.12, 0.32, 0.62)
			apron_color = Color(0.85, 0.15, 0.15)
		4: # Frostbite Glaciers (Heavy insulated white fur)
			robe_color = Color(0.85, 0.85, 0.88)
			apron_color = Color(0.55, 0.55, 0.60)
		7: # Neon Ruins (Cybertech Black & Cyan)
			robe_color = Color(0.12, 0.12, 0.15)
			apron_color = Color(0.0, 0.95, 0.95) # Glowing cyan apron
			jewel_color = Color(0.95, 0.0, 0.95) # Glowing magenta visor gem
		8: # Swamp of Sighs (Alchemist Mossy Mud)
			robe_color = Color(0.28, 0.22, 0.15)
			apron_color = Color(0.18, 0.32, 0.15) # Mossy green apron
		9: # Cloud Kingdom (Sky White & Gold)
			robe_color = Color(0.95, 0.98, 1.0)
			apron_color = Color(1.0, 0.85, 0.2)
	
	# 1. Base Legs & Feet
	_create_box(_body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), boots_color)
	
	# 2. Main Torso Robe
	_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), robe_color)
	
	# 3. Double-Layered Front Apron (Adds volume and thickness)
	_create_box(_body_bob_node, Vector3(0.3, 0.5, 0.05), Vector3(0, 0.38, -0.23), apron_color)
	_create_box(_body_bob_node, Vector3(0.34, 0.08, 0.48), Vector3(0, 0.45, 0), sash_color) # Waist sash band
	
	# 4. Head Joint & Face Details
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.05, 0)
	_body_bob_node.add_child(_head_node)
	
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color) # Face
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), skin_color * 0.9) # Nose
	
	# Blinking Eyes (Cyan-blue pupils)
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.18, 0.42, 0.68))
	
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.18, 0.42, 0.68))
	
	# 5. Arms Folded (Horizontal gold sleeves)
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.65, -0.25)
	_body_bob_node.add_child(_arms_node)
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), apron_color)
	
	# 6. Biome-Specific Turban and Head Accessories
	_build_custom_headwear(biome_id, turban_color, jewel_color, robe_color)


## Procedural Headwear: Generates turbans, crowns, cowls, or hats based on coordinates.
func _build_custom_headwear(biome_id: int, turban_color: Color, jewel_color: Color, robe_color: Color) -> void:
	match biome_id:
		0: # Bay of Sails (Sailor Bandana cap)
			_create_box(_head_node, Vector3(0.38, 0.10, 0.38), Vector3(0, 0.35, 0), Color(0.85, 0.15, 0.15))
			_create_box(_head_node, Vector3(0.10, 0.10, 0.15), Vector3(0, 0.28, 0.22), Color(0.85, 0.15, 0.15))
		4: # Frostbite Glaciers (Fur-lined polar winter cowl)
			_create_box(_head_node, Vector3(0.39, 0.39, 0.39), Vector3(0, 0.185, 0.02), robe_color)
			_create_box(_head_node, Vector3(0.42, 0.42, 0.10), Vector3(0, 0.185, -0.15), Color(0.98, 0.98, 0.98))
		7: # Neon Ruins (Techwear glowing visor)
			_create_box(_head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.36, 0), Color(0.12, 0.12, 0.15))
			_create_box(_head_node, Vector3(0.08, 0.08, 0.04), Vector3(0, 0.36, -0.20), jewel_color)
		8: # Swamp of Sighs (Alchemist tattered cowl)
			_create_box(_head_node, Vector3(0.39, 0.39, 0.39), Vector3(0, 0.185, 0.02), robe_color)
			_create_box(_head_node, Vector3(0.32, 0.08, 0.32), Vector3(0, 0.39, -0.05), Color(0.18, 0.32, 0.15))
		9: # Cloud Kingdom (Golden Crown)
			_create_box(_head_node, Vector3(0.38, 0.06, 0.38), Vector3(0, 0.32, 0), Color(1.0, 0.85, 0.2))
			_create_box(_head_node, Vector3(0.06, 0.12, 0.06), Vector3(0, 0.38, -0.18), Color(1.0, 0.85, 0.2))
		_: # Default Plains (Classic Silk Turban & Emerald Gem)
			_create_box(_head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.36, 0), turban_color)
			_create_box(_head_node, Vector3(0.22, 0.08, 0.22), Vector3(0, 0.44, 0), turban_color)
			# Mounted glowing emerald jewel on the forehead
			_create_box(_head_node, Vector3(0.06, 0.08, 0.04), Vector3(0, 0.36, -0.20), jewel_color)


func _get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.5, 0.575)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.75, 0)


func _setup_floating_bubble() -> void:
	var sb_script: Script = load("res://src/Infrastructure/UI/SpeechBubble.gd")
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", "RIGHT-CLICK TO TRADE!")


## Public Interaction: Triggers centralized trading dialogue overlays.
func interact(player_node: CharacterBody3D) -> void:
	var hud = player_node.get("hud")
	if is_instance_valid(hud):
		var intro_node: Resource = DialogueService.get_dialogue_node("merchant_intro")
		if intro_node == null:
			print("[MerchantEntity] Dialogue node was null! Initializing local fallback...")
			DialogueRegistry.initialize_dialogue_database()
			intro_node = DialogueService.get_dialogue_node("merchant_intro")
			
		if intro_node != null:
			hud.call("open_dialogue", intro_node, "Merchant")


## Queries coordinate biomes.
func _detect_current_biome() -> int:
	var world_controller = get_parent()
	var default_biome_id: int = 2
	
	if is_instance_valid(world_controller) and "generator" in world_controller:
		var generator = world_controller.get("generator")
		if generator != null:
			var terrain_noise = generator.get("_terrain_noise")
			if terrain_noise != null:
				var profile = BiomeService.evaluate_coordinate(
					int(round(global_position.x)), 
					int(round(global_position.z)), 
					terrain_noise
				)
				return profile.biome_id
				
	return default_biome_id


func _can_socialize() -> bool:
	return true
