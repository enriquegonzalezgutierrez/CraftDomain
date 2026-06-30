# ==============================================================================
# Project: CraftDomain
# Description: Villager NPC physics controller. Generates unique 3D visual 
#              outfits dynamically based on its home biome coordinate, 
#              ensuring extreme environmental variety.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Inherits PassiveEntity and 
#                fully satisfies all base physics, AI state, and blinking loops.
#              - Single Responsibility Principle (SRP): Handles exclusively villager 
#                visual variations and dialog triggers.
#              - Open-Closed Principle (OCP) & i18n: Exclusively uses translation 
#                keys to prevent hardcoded string leakage in codebase.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/VillagerEntity.gd
# ==============================================================================
class_name VillagerEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 3) # 3 Hearts of health
	name = "Entity_VILLAGER"


## Concrete Implementation: Assembles a procedural 3D model, applying unique 
## clothes, accessories, and headwear based on the local biome sector.
func _build_visual_representation() -> void:
	var biome_id := _detect_current_biome()
	
	# Fallback Colors
	var skin_color := variant_skin_color
	var hair_color := variant_hair_color
	var robe_color := variant_clothing_color
	var boots_color := Color(0.15, 0.1, 0.08) # Dark leather
	var accessory_color := Color(0.18, 0.12, 0.08) # Dark belt
	
	# 1. Base Legs / Feet
	_create_box(_body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), boots_color)
	
	# 2. Torso Robe (Customized by biome)
	_build_custom_torso_robe(biome_id, robe_color, accessory_color)
	
	# 3. Head Joint & Face Details
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.05, 0)
	_body_bob_node.add_child(_head_node)
	
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color) # Face
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), skin_color * 0.9) # Nose
	
	# Deep-set Blinking Eyes
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	
	# 4. Folded Arms (Classic Villager folded pose)
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.65, -0.23)
	_body_bob_node.add_child(_arms_node)
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), robe_color * 0.8)
	
	# 5. Biome-Specific Headwear & Accessories
	_build_custom_headwear(biome_id, hair_color)


## Queries the parent world controllers to detect which biome this entity spawned in.
func _detect_current_biome() -> int:
	var world_controller = get_parent()
	var default_biome_id: int = 2 # Default to Golden Bazaar
	
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


## Procedural Torso Customizer: Generates unique clothing shapes and palettes.
func _build_custom_torso_robe(biome_id: int, base_color: Color, accessory_color: Color) -> void:
	match biome_id:
		0: # Bay of Sails (Sailor Stripes)
			_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color.WHITE)
			# Blue stripes overlay
			_create_box(_body_bob_node, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.75, 0), Color(0.12, 0.45, 0.82))
			_create_box(_body_bob_node, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.50, 0), Color(0.12, 0.45, 0.82))
			_create_box(_body_bob_node, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.25, 0), Color(0.12, 0.45, 0.82))
		1: # Warp Plateau (Mario Plumber Dungarees)
			_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.85, 0.12, 0.12)) # Red shirt
			_create_box(_body_bob_node, Vector3(0.47, 0.42, 0.47), Vector3(0, 0.36, 0), Color(0.15, 0.35, 0.72)) # Denim pants
			# Yellow gold buttons
			_create_box(_body_bob_node, Vector3(0.06, 0.06, 0.03), Vector3(-0.11, 0.45, -0.24), Color(1.0, 0.85, 0.2))
			_create_box(_body_bob_node, Vector3(0.06, 0.06, 0.03), Vector3(0.11, 0.45, -0.24), Color(1.0, 0.85, 0.2))
		4: # Frostbite Glaciers (Thermal fur-lined overalls)
			_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.82, 0.82, 0.85)) # Winter white coat
			_create_box(_body_bob_node, Vector3(0.48, 0.10, 0.48), Vector3(0, 0.15, 0), Color(0.98, 0.98, 0.98)) # Fluffy fur trim
		5: # Whispering Redwood Forest (Ranger Green tunic)
			_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.18, 0.45, 0.15))
			_create_box(_body_bob_node, Vector3(0.48, 0.06, 0.48), Vector3(0, 0.45, 0), accessory_color) # Leather belt
		7: # Neon Ruins (Cyberpunk Techwear)
			_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.12, 0.12, 0.15)) # Dark carbon jacket
			# Cybernetic neon pipelines
			_create_box(_body_bob_node, Vector3(0.47, 0.06, 0.47), Vector3(0, 0.65, 0), Color(0.0, 0.95, 0.95)) # Cyan stripe
			_create_box(_body_bob_node, Vector3(0.47, 0.06, 0.47), Vector3(0, 0.45, 0), Color(0.95, 0.0, 0.95)) # Magenta stripe
		8: # Swamp of Sighs (Murky Mud robes)
			_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.28, 0.22, 0.15)) # Mud brown
			_create_box(_body_bob_node, Vector3(0.47, 0.18, 0.47), Vector3(0, 0.32, 0), Color(0.18, 0.15, 0.12)) # Dark patches
		9: # Cloud Kingdom (Sky Clouds Tunic)
			_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.95, 0.98, 1.0)) # Cloud white
			_create_box(_body_bob_node, Vector3(0.48, 0.15, 0.48), Vector3(0, 0.80, 0), Color(1.0, 0.98, 0.85)) # Light gold trim
		_: # Default Plains (Golden Bazaar / Others)
			_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), base_color)
			# Leather belt with iron buckle using the accessory_color variable
			_create_box(_body_bob_node, Vector3(0.48, 0.08, 0.48), Vector3(0, 0.45, 0), accessory_color)
			_create_box(_body_bob_node, Vector3(0.12, 0.1, 0.05), Vector3(0, 0.45, -0.25), Color(0.65, 0.65, 0.7))


## Procedural Headwear Customizer: Generates unique caps, visors, halos, and hoods.
func _build_custom_headwear(biome_id: int, hair_color: Color) -> void:
	match biome_id:
		0: # Bay of Sails (Sailor Bandana)
			_create_box(_head_node, Vector3(0.38, 0.10, 0.38), Vector3(0, 0.35, 0), Color(0.12, 0.45, 0.82)) # Blue band
			_create_box(_head_node, Vector3(0.10, 0.10, 0.15), Vector3(0, 0.28, 0.22), Color(0.12, 0.45, 0.82)) # Bandana knot
		1: # Warp Plateau (Mario Plumber Cap)
			_create_box(_head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.36, 0), Color(0.85, 0.12, 0.12)) # Red dome
			_create_box(_head_node, Vector3(0.38, 0.04, 0.12), Vector3(0, 0.32, -0.22), Color(0.85, 0.12, 0.12)) # Visor brim
			_create_box(_head_node, Vector3(0.12, 0.10, 0.03), Vector3(0, 0.36, -0.20), Color.WHITE) # White decal plate
		4: # Frostbite Glaciers (Winter Fur-Hood)
			_create_box(_head_node, Vector3(0.39, 0.39, 0.39), Vector3(0, 0.185, 0.02), Color(0.82, 0.82, 0.85)) # Winter hood base
			_create_box(_head_node, Vector3(0.42, 0.42, 0.10), Vector3(0, 0.185, -0.15), Color(0.98, 0.98, 0.98)) # Fluffy fur rim
		5: # Whispering Redwood Forest (Elven Leaf Crown)
			_create_box(_head_node, Vector3(0.38, 0.05, 0.38), Vector3(0, 0.30, 0), Color(0.85, 0.6, 0.15)) # Golden crown band
			_create_box(_head_node, Vector3(0.08, 0.14, 0.04), Vector3(0, 0.38, -0.19), Color(0.18, 0.45, 0.15)) # Leaf details
		7: # Neon Ruins (Cyber Visor)
			# Sleek cyan glowing tech-visor over eyes
			_create_box(_head_node, Vector3(0.38, 0.10, 0.08), Vector3(0, 0.19, -0.16), Color(0.0, 0.95, 0.95))
		8: # Swamp of Sighs (Murky Mud Tattered Hood)
			_create_box(_head_node, Vector3(0.39, 0.39, 0.39), Vector3(0, 0.185, 0.02), Color(0.28, 0.22, 0.15))
			_create_box(_head_node, Vector3(0.32, 0.08, 0.32), Vector3(0, 0.39, -0.05), Color(0.18, 0.15, 0.12))
		9: # Cloud Kingdom (Angelic Golden Halo)
			_create_box(_head_node, Vector3(0.32, 0.03, 0.32), Vector3(0, 0.52, 0), Color(1.0, 0.85, 0.2)) # Glowing golden halo ring
		_: # Default Plains (Procedural Hair Styles)
			# Hair base plate
			_create_box(_head_node, Vector3(0.38, 0.18, 0.38), Vector3(0, 0.30, 0.03), hair_color)
			# Hair sideburns
			_create_box(_head_node, Vector3(0.06, 0.20, 0.38), Vector3(-0.18, 0.18, 0.03), hair_color)
			_create_box(_head_node, Vector3(0.06, 0.20, 0.38), Vector3(0.18, 0.18, 0.03), hair_color)


## Public Gaze Interaction: Triggers localized village dialogue progression.
## REFACTORING: Replaced hardcoded dialogue text with dynamic i18n translation keys.
func interact(player_node: CharacterBody3D) -> void:
	var active_q := QuestService.get_active_quest()
	
	# Quest completion trigger for "1. The Lost Bazaar"
	if active_q != null and active_q.quest_id == "lost_bazaar":
		QuestService.complete_active_quest(player_node)
		
		var complete_node := DialogueNode.new()
		complete_node.node_id = "villager_quest_complete"
		complete_node.text = "DIALOGUE_VILLAGER_QUEST_COMPLETE"
		DialogueService.register_node(complete_node)
		
		var hud = player_node.get("hud")
		if is_instance_valid(hud):
			hud.call("open_dialogue", complete_node, "Villager")
	else:
		# Standard localized chat
		var hud = player_node.get("hud")
		if is_instance_valid(hud):
			var intro_node: Resource = DialogueService.get_dialogue_node("villager_intro")
			if intro_node == null:
				var fallback_node := DialogueNode.new()
				fallback_node.node_id = "villager_intro"
				fallback_node.text = "DIALOGUE_VILLAGER_INTRO"
				DialogueService.register_node(fallback_node)
				intro_node = fallback_node
			hud.call("open_dialogue", intro_node, "Villager")


func _can_socialize() -> bool:
	return true
