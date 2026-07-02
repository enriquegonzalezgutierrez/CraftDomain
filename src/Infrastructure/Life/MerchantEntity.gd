# ==============================================================================
# Project: CraftDomain
# Description: Merchant NPC physics controller. Generates highly customized 
#              clothes, aprons, and turbans based on its home biome coordinate.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Inherits PassiveEntity.
#              - Single Responsibility Principle (SRP): Delegates rendering setups 
#                and AI state execution to specialized sibling components.
#              BUG FIX (i18n): Replaced hardcoded name string with localized 
#              translation keys to maintain strict multi-language support.
#              BUG FIX (PROPERTIES): Corrected `profile.id` to `profile.biome_id` 
#              in `_detect_current_biome()` to match the BiomeProfile struct.
#              UX MODELING OVERHAUL (CLAY MERCHAND):
#              - Upgraded visual boxes: added a double-layered silk turban, 
#                an elegant gold-plated front apron, and a persistent 3D leather 
#                money pouch (zurrón) hanging from his waist belt.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MerchantEntity.gd
# ==============================================================================
class_name MerchantEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 3) # 3 Hearts of health
	name = "Entity_MERCHANT"


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	var biome_id := _detect_current_biome()
	
	# Extract procedural color parameters calculated on boot by the visual component
	var skin_color: Color = visual_component.variant_skin_color
	var sash_color: Color = visual_component.variant_clothing_color
	
	# Fallback accessory colors
	var robe_color := Color(0.45, 0.15, 0.6)         # Royal violet robe
	var apron_color := Color(0.85, 0.6, 0.15)        # Golden yellow apron
	var boots_color := Color(0.15, 0.1, 0.08)        # Dark leather boots
	var turban_color := Color(0.9, 0.82, 0.45)       # Soft gold turban
	var jewel_color := Color(0.92, 0.12, 0.15)       # Glowing red ruby gem
	var leather_pouch_color := Color(0.35, 0.22, 0.15) # Leather brown for the zurrón
	
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
			apron_color = Color(0.0, 0.95, 0.95) 
			jewel_color = Color(0.95, 0.0, 0.95) 
		8: # Swamp of Sighs (Alchemist Mossy Mud)
			robe_color = Color(0.28, 0.22, 0.15)
			apron_color = Color(0.18, 0.32, 0.15) 
		9: # Cloud Kingdom (Sky White & Gold)
			robe_color = Color(0.95, 0.98, 1.0)
			apron_color = Color(1.0, 0.85, 0.2)
	
	# 1. Base Legs & Feet
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), boots_color)
	
	# 2. Main Torso Robe
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), robe_color)
	
	# 3. Double-Layered Front Apron (Adds volume and thickness)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.3, 0.5, 0.05), Vector3(0, 0.38, -0.23), apron_color)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.34, 0.08, 0.48), Vector3(0, 0.45, 0), sash_color) # Waist sash band
	
	# --- ZURRÓN OVERHAUL: Spawns a 3D leather coin pouch hanging off his left hip ---
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.12, 0.18, 0.12), Vector3(-0.24, 0.38, -0.15), leather_pouch_color)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.04, 0.08, 0.04), Vector3(-0.24, 0.49, -0.12), Color.BLACK) # Pouch cord strap
	
	# 4. Head Joint Setup
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "HumanHead"
	visual_component.head_node.position = Vector3(0, 1.05, 0)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	visual_component.create_box(visual_component.head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color) # Face
	visual_component.create_box(visual_component.head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), skin_color * 0.9) # Nose
	
	# Blinking Eyes (Assigned to visual component tracking)
	visual_component.left_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	visual_component.create_box(visual_component.left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.18, 0.42, 0.68))
	
	visual_component.right_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	visual_component.create_box(visual_component.right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.18, 0.42, 0.68))
	
	# 5. Arms Folded (Horizontal sleeves)
	visual_component.arms_node = Node3D.new()
	visual_component.arms_node.name = "ArmsJoint"
	visual_component.arms_node.position = Vector3(0, 0.65, -0.25)
	visual_component.body_bob_node.add_child(visual_component.arms_node)
	visual_component.create_box(visual_component.arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), apron_color)
	
	# 6. Biome-Specific Turban and Head Accessories
	_build_custom_headwear(biome_id, turban_color, jewel_color, robe_color)


## Procedural Headwear: Generates turbans, crowns, cowls, or hats based on coordinates.
func _build_custom_headwear(biome_id: int, turban_color: Color, jewel_color: Color, robe_color: Color) -> void:
	match biome_id:
		0: # Bay of Sails (Sailor Bandana cap)
			var _un1 := visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.10, 0.38), Vector3(0, 0.35, 0), Color(0.85, 0.15, 0.15))
			var _un2 := visual_component.create_box(visual_component.head_node, Vector3(0.10, 0.10, 0.15), Vector3(0, 0.28, 0.22), Color(0.85, 0.15, 0.15))
		4: # Frostbite Glaciers (Heavy insulated white fur)
			var _un3 := visual_component.create_box(visual_component.head_node, Vector3(0.39, 0.39, 0.39), Vector3(0, 0.185, 0.02), robe_color)
			var _un4 := visual_component.create_box(visual_component.head_node, Vector3(0.42, 0.42, 0.10), Vector3(0, 0.185, -0.15), Color(0.98, 0.98, 0.98))
		7: # Neon Ruins (Techwear glowing visor)
			var _un5 := visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.36, 0), Color(0.12, 0.12, 0.15))
			var _un6 := visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.04), Vector3(0, 0.36, -0.20), jewel_color)
		8: # Swamp of Sighs (Alchemist tattered cowl)
			var _un7 := visual_component.create_box(visual_component.head_node, Vector3(0.39, 0.39, 0.39), Vector3(0, 0.185, 0.02), robe_color)
			var _un8 := visual_component.create_box(visual_component.head_node, Vector3(0.32, 0.08, 0.32), Vector3(0, 0.39, -0.05), Color(0.18, 0.32, 0.15))
		9: # Cloud Kingdom (Golden Crown)
			var _un9 := visual_component.create_box(visual_component.head_node, Vector3(0.32, 0.03, 0.32), Vector3(0, 0.52, 0), Color(1.0, 0.85, 0.2))
			var _un10 := visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.12, 0.06), Vector3(0, 0.38, -0.18), Color(1.0, 0.85, 0.2))
		_: # Default Plains (Classic Silk Turban & Emerald Gem)
			# Double-layered silk turban cap
			var _un11 := visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.36, 0), turban_color)
			var _un12 := visual_component.create_box(visual_component.head_node, Vector3(0.24, 0.08, 0.24), Vector3(0, 0.44, 0), turban_color)
			# Mounted glowing emerald jewel on the forehead
			var _un13 := visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.08, 0.04), Vector3(0, 0.36, -0.20), jewel_color)


## Public Interaction: Triggers centralized trading dialogue overlays.
func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueService.get_dialogue_node("merchant_intro")
		if intro_node == null:
			print("[MerchantEntity] Dialogue database was null! Building dynamic database...")
			DialogueRegistry.initialize_dialogue_database()
			intro_node = DialogueService.get_dialogue_node("merchant_intro")
			
		if intro_node != null:
			hud.open_dialogue(intro_node, "NPC_NAME_MERCHANT", self)


func _setup_floating_bubble() -> void:
	var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", tr("BUBBLE_TRADE"))


## Queries coordinate biomes.
func _detect_current_biome() -> int:
	# FIX: Explicit static typing on world controller reference
	var world_controller_ref: Node = get_parent() as Node
	var default_biome_id: int = 2
	
	if is_instance_valid(world_controller_ref) and "generator" in world_controller_ref:
		# FIX: Explicit static typing on world generator reference
		var generator: WorldGenerator = world_controller_ref.get("generator") as WorldGenerator
		if generator != null:
			# FIX: Explicit static typing on terrain noise provider
			var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
			if terrain_noise != null:
				var profile := BiomeService.evaluate_coordinate(
					int(round(global_position.x)), 
					int(round(global_position.z)), 
					terrain_noise
				)
				return profile.biome_id
				
	return default_biome_id


func _can_socialize() -> bool:
	return true
