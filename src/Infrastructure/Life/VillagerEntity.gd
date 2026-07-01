# ==============================================================================
# Project: CraftDomain
# Description: Villager NPC physics controller. Generates unique 3D visual 
#              outfits dynamically based on its home biome coordinate.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Inherits PassiveEntity and 
#                fully satisfies all base physics and signals.
#              - Single Responsibility Principle (SRP): Delegates rendering setups 
#                and AI state execution to specialized sibling components.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/VillagerEntity.gd
# ==============================================================================
class_name VillagerEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 3) # 3 Hearts of health
	name = "Entity_VILLAGER"


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	var biome_id := _detect_current_biome()
	
	# Extract procedural color parameters calculated on boot by the visual component
	var skin_color: Color = visual_component.variant_skin_color
	var hair_color: Color = visual_component.variant_hair_color
	var robe_color: Color = visual_component.variant_clothing_color
	
	# Fallback accessory colors
	var boots_color := Color(0.15, 0.1, 0.08) 
	var accessory_color := Color(0.18, 0.12, 0.08) 
	
	# 1. Base Legs / Feet (Attached to the bobbing joint)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), boots_color)
	
	# 2. Torso Robe (Customized dynamically by biome)
	_build_custom_torso_robe(biome_id, robe_color, accessory_color)
	
	# 3. Head Joint Setup
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "HumanHead"
	visual_component.head_node.position = Vector3(0, 1.05, 0)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	# Face blocks
	visual_component.create_box(visual_component.head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color) # Face core
	visual_component.create_box(visual_component.head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), skin_color * 0.9) # Nose
	
	# Deep-set Blinking Eyes (Assigned to visual component tracking)
	visual_component.left_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	visual_component.create_box(visual_component.left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	
	visual_component.right_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	visual_component.create_box(visual_component.right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	
	# 4. Folded Arms (Classic Villager folded pose joint)
	visual_component.arms_node = Node3D.new()
	visual_component.arms_node.name = "ArmsJoint"
	visual_component.arms_node.position = Vector3(0, 0.65, -0.23)
	visual_component.body_bob_node.add_child(visual_component.arms_node)
	visual_component.create_box(visual_component.arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), robe_color * 0.8)
	
	# 5. Biome-Specific Headwear & Accessories
	_build_custom_headwear(biome_id, hair_color)


## Procedural Torso Customizer: Generates unique clothing shapes and palettes.
func _build_custom_torso_robe(biome_id: int, base_color: Color, accessory_color: Color) -> void:
	match biome_id:
		0: # Bay of Sails (Sailor Stripes)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color.WHITE)
			# Blue stripes overlay
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.75, 0), Color(0.12, 0.45, 0.82))
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.50, 0), Color(0.12, 0.45, 0.82))
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.25, 0), Color(0.12, 0.45, 0.82))
		1: # Warp Plateau (Mario Plumber Dungarees)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.85, 0.12, 0.12)) # Red shirt
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.42, 0.47), Vector3(0, 0.36, 0), Color(0.15, 0.35, 0.72)) # Denim pants
			# Yellow gold buttons
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.06, 0.06, 0.03), Vector3(-0.11, 0.45, -0.24), Color(1.0, 0.85, 0.2))
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.06, 0.06, 0.03), Vector3(0.11, 0.45, -0.24), Color(1.0, 0.85, 0.2))
		4: # Frostbite Glaciers (Thermal fur-lined overalls)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.82, 0.82, 0.85)) # Winter white coat
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.48, 0.10, 0.48), Vector3(0, 0.15, 0), Color(0.98, 0.98, 0.98)) # Fluffy fur trim
		5: # Whispering Redwood Forest (Ranger Green tunic)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.18, 0.45, 0.15))
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.48, 0.06, 0.48), Vector3(0, 0.45, 0), accessory_color) # Leather belt
		7: # Neon Ruins (Cyberpunk Techwear)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.12, 0.12, 0.15)) # Dark carbon jacket
			# Cybernetic neon pipelines
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.06, 0.47), Vector3(0, 0.65, 0), Color(0.0, 0.95, 0.95)) # Cyan stripe
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.06, 0.47), Vector3(0, 0.45, 0), Color(0.95, 0.0, 0.95)) # Magenta stripe
		8: # Swamp of Sighs (Murky Mud robes)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.28, 0.22, 0.15)) # Mud brown
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.18, 0.47), Vector3(0, 0.32, 0), Color(0.18, 0.15, 0.12)) # Dark patches
		9: # Cloud Kingdom (Sky Clouds Tunic)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.95, 0.98, 1.0)) # Cloud white
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.48, 0.15, 0.48), Vector3(0, 0.80, 0), Color(1.0, 0.98, 0.85)) # Light gold trim
		_: # Default Plains
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), base_color)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.48, 0.08, 0.48), Vector3(0, 0.45, 0), accessory_color)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.12, 0.1, 0.05), Vector3(0, 0.45, -0.25), Color(0.65, 0.65, 0.7))


## Procedural Headwear Customizer: Generates unique caps, visors, halos, and hoods.
func _build_custom_headwear(biome_id: int, hair_color: Color) -> void:
	match biome_id:
		0: # Bay of Sails (Sailor Bandana)
			visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.10, 0.38), Vector3(0, 0.35, 0), Color(0.12, 0.45, 0.82)) 
			visual_component.create_box(visual_component.head_node, Vector3(0.10, 0.10, 0.15), Vector3(0, 0.28, 0.22), Color(0.12, 0.45, 0.82)) 
		1: # Warp Plateau (Mario Plumber Cap)
			visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.36, 0), Color(0.85, 0.12, 0.12)) 
			visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.04, 0.12), Vector3(0, 0.32, -0.22), Color(0.85, 0.12, 0.12)) 
			visual_component.create_box(visual_component.head_node, Vector3(0.12, 0.10, 0.03), Vector3(0, 0.36, -0.20), Color.WHITE) 
		4: # Frostbite Glaciers (Winter Fur-Hood)
			visual_component.create_box(visual_component.head_node, Vector3(0.39, 0.39, 0.39), Vector3(0, 0.185, 0.02), Color(0.82, 0.82, 0.85)) 
			visual_component.create_box(visual_component.head_node, Vector3(0.42, 0.42, 0.10), Vector3(0, 0.185, -0.15), Color(0.98, 0.98, 0.98)) 
		5: # Whispering Redwood Forest (Elven Leaf Crown)
			visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.05, 0.38), Vector3(0, 0.30, 0), Color(0.85, 0.6, 0.15)) 
			visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.14, 0.04), Vector3(0, 0.38, -0.19), Color(0.18, 0.45, 0.15)) 
		7: # Neon Ruins (Cyber Visor)
			visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.10, 0.08), Vector3(0, 0.19, -0.16), Color(0.0, 0.95, 0.95))
		8: # Swamp of Sighs (Murky Mud Tattered Hood)
			visual_component.create_box(visual_component.head_node, Vector3(0.39, 0.39, 0.39), Vector3(0, 0.185, 0.02), Color(0.28, 0.22, 0.15))
			visual_component.create_box(visual_component.head_node, Vector3(0.32, 0.08, 0.32), Vector3(0, 0.39, -0.05), Color(0.18, 0.15, 0.12))
		9: # Cloud Kingdom (Angelic Golden Halo)
			visual_component.create_box(visual_component.head_node, Vector3(0.32, 0.03, 0.32), Vector3(0, 0.52, 0), Color(1.0, 0.85, 0.2)) 
		_: # Default Plains
			visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.18, 0.38), Vector3(0, 0.30, 0.03), hair_color)
			visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.20, 0.38), Vector3(-0.18, 0.18, 0.03), hair_color)
			visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.20, 0.38), Vector3(0.18, 0.18, 0.03), hair_color)


## Public Gaze Interaction: Triggers localized village dialogue progression.
func interact(player_node: CharacterBody3D) -> void:
	var active_q := QuestService.get_active_quest()
	
	# Quest completion trigger for "1. The Lost Bazaar"
	if active_q != null and active_q.quest_id == "lost_bazaar":
		QuestService.complete_active_quest(player_node)
		
		var complete_node := DialogueNode.new()
		complete_node.node_id = "villager_quest_complete"
		complete_node.text = "DIALOGUE_VILLAGER_QUEST_COMPLETE"
		DialogueService.register_node(complete_node)
		
		var hud := player_node.get("hud") as PlayerHUD
		if is_instance_valid(hud):
			hud.open_dialogue(complete_node, "Villager", self)
	else:
		# Standard procedural dialogue routing
		var hud := player_node.get("hud") as PlayerHUD
		if is_instance_valid(hud):
			var intro_node := DialogueNode.new()
			intro_node.node_id = "villager_intro_temp"
			intro_node.text = _select_procedural_greeting_key()
			
			hud.open_dialogue(intro_node, "Villager", self)


## Selects a unique localized dialogue key based on time, biome, and variety index.
func _select_procedural_greeting_key() -> String:
	var celestial := get_node_or_null("/root/Bootstrap/CelestialService")
	var is_night := false
	if is_instance_valid(celestial) and celestial.has_method("is_night_time"):
		is_night = celestial.call("is_night_time") as bool
		
	if is_night:
		return "DIALOGUE_VILLAGER_NIGHT"
		
	var biome_id := _detect_current_biome()
	match biome_id:
		0: return "DIALOGUE_VILLAGER_OCEAN"     
		4: return "DIALOGUE_VILLAGER_GLACIERS"   
		7: return "DIALOGUE_VILLAGER_NEON"        
		8: return "DIALOGUE_VILLAGER_SWAMP"       
		9: return "DIALOGUE_VILLAGER_CLOUD"       
		_:
			var variety_index := npc_seed % 3
			match variety_index:
				0: return "DIALOGUE_VILLAGER_PLAINS_A"
				1: return "DIALOGUE_VILLAGER_PLAINS_B"
				_: return "DIALOGUE_VILLAGER_PLAINS_C"


func _setup_floating_bubble() -> void:
	var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", tr("BUBBLE_TALK"))


## Queries coordinate biomes.
func _detect_current_biome() -> int:
	var world_controller_ref = get_parent()
	var default_biome_id: int = 2
	
	if is_instance_valid(world_controller_ref) and "generator" in world_controller_ref:
		var generator = world_controller_ref.get("generator")
		if generator != null:
			var terrain_noise = generator.get("_terrain_noise")
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
