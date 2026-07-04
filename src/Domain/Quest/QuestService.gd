# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Service acting as a Registry and Coordinator for 
#              game Quests, tracking active objectives and global progression.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Isolates quest registry 
#                and progression rules.
#              - Open-Closed Principle (OCP): Dynamic resource routing maps 
#                gathering targets to coordinate hotspots without altering the UI.
#              REACTIVE HOTSPOT ROUTING:
#              - Added `_update_gathering_target_position` to dynamically route 
#                gathering/mining quests directly to geographical resource zones 
#                (Nether Outpost for Lava, Steve's Cabin Fields for Crops), 
#                guaranteeing players always have navigation guidance.
#              EXACT JSON TARGET COMPLIANCE:
#              - Handled all resource types from both campaign.json and expeditions.json
#                (Stone, Dirt, Wood, Leaves, Water, Lava) with targeted biome routing.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Quest/QuestService.gd
# ==============================================================================
class_name QuestService
extends RefCounted

## Dynamic database mapping Quest IDs to Quest resources
static var _quests: Dictionary = {}

## The currently active quest being tracked by the player
static var _active_quest: Quest

## Registers a quest into the system database (SRP compliant)
static func register_quest(quest: Quest) -> void:
	if quest != null and quest.quest_id != "":
		_quests[quest.quest_id] = quest


## Returns a registered quest by its ID
static func get_quest(quest_id: String) -> Quest:
	return _quests.get(quest_id) as Quest


## Sets the currently active quest, updates its status, and maps resource targets
static func set_active_quest(quest_id: String, player_pos: Vector3 = Vector3.ZERO) -> void:
	if _quests.has(quest_id):
		var quest: Quest = _quests[quest_id]
		if quest.status != Quest.Status.COMPLETED:
			_active_quest = quest
			_active_quest.status = Quest.Status.ACTIVE
			
			# Dynamic Resource Routing: Map coordinates to resource hotspots if applicable
			_update_gathering_target_position(_active_quest, player_pos)
			print("[QuestService] Active Quest changed to: ", _active_quest.title)


## Returns the currently tracked active quest (null if none)
static func get_active_quest() -> Quest:
	return _active_quest


## Clears the active quest track (Used when loading a fully completed campaign save)
static func clear_active_quest() -> void:
	_active_quest = null
	print("[QuestService] Active quest cleared (Campaign previously completed).")


## Marks the active quest as completed, grants rewards, and chains the next one
static func complete_active_quest(player_node: CharacterBody3D = null) -> void:
	if _active_quest != null:
		_active_quest.status = Quest.Status.COMPLETED
		print("[QuestService] Active Quest successfully completed: ", _active_quest.title)
		
		# Grant inventory rewards safely if the player instance is provided
		if player_node != null and _active_quest.reward_item_index >= 0:
			var inv: IInventory = player_node.get("inventory")
			if is_instance_valid(inv):
				# Reward items added safely. The HUD will update automatically 
				# by listening to the `inventory_changed` signal.
				var _success := inv.add_item(_active_quest.reward_item_index, _active_quest.reward_quantity)
				
		# Cache the next quest link before clearing
		var next_id := _active_quest.next_quest_id
		_active_quest = null
		
		# Auto-trigger next quest in the chain
		if next_id != "":
			set_active_quest(next_id, player_node.global_position if player_node != null else Vector3.ZERO)


# ==============================================================================
# DYNAMIC RESOURCE HOTSPOT ROUTING (OCP Compliant)
# ==============================================================================

## Evaluates the active gathering quest requirements and dynamically sets the 
## target position pointing directly to the closest natural resource hotspot.
static func _update_gathering_target_position(quest: Quest, _player_pos: Vector3) -> void:
	if quest == null or quest.required_item_index == -1:
		return
		
	# Fixed high-concentration POI landmarks coordinates on the map
	var nether_portal_lava := Vector3(-300.0, 9.5, -300.0) # Giant obsidian pools of natural Lava (ID 15)
	var steves_cabin_fields := Vector3(300.0, 11.5, -300.0) # Symmetrical golden wheat plots ready to harvest (ID 18/20)
	var craggy_mines_stone := Vector3(-150.0, 15.0, -150.0) # Craggy Peaks: Mountains, Stone, Caverns (ID 1)
	var bay_of_sails_water := Vector3(0.0, 6.0, 0.0) # Bay of Sails: Ocean, Water, Sand (ID 6, 7)
	
	match quest.required_item_index:
		0, 1, 21: # Stone, Coal Ore (Including 0 representing stone proxy in some campaign tasks)
			quest.target_position = craggy_mines_stone
			print("[QuestService] Mapped gathering target for '", quest.quest_id, "' to Craggy Peaks Mountains: ", quest.target_position)
			
		2: # Dirt
			quest.target_position = steves_cabin_fields
			print("[QuestService] Mapped gathering target for '", quest.quest_id, "' to Steve's Valley fertile soils: ", quest.target_position)
			
		4, 5: # Wood, Leaves (Like thatch_roof)
			quest.target_position = steves_cabin_fields # Points near Steve's valley village, surrounded by oak and sakura trees
			print("[QuestService] Mapped gathering target for '", quest.quest_id, "' to Golden Bazaar Forests: ", quest.target_position)
			
		6, 7: # Water, Sand (Like polar_forager or lava_feast)
			quest.target_position = bay_of_sails_water
			print("[QuestService] Mapped gathering target for '", quest.quest_id, "' to Bay of Sails Shores: ", quest.target_position)
			
		15: # Lava
			quest.target_position = nether_portal_lava
			print("[QuestService] Mapped gathering target for '", quest.quest_id, "' to Nether Outpost Lava: ", quest.target_position)
			
		18, 20: # Seeds, Crops
			quest.target_position = steves_cabin_fields
			print("[QuestService] Mapped gathering target for '", quest.quest_id, "' to Steve's Cabin Fields: ", quest.target_position)
