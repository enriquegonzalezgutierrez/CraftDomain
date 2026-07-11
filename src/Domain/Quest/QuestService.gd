# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Quest System / Pure Business Rules)
# Class: QuestService
# Description: Pure Domain Service acting as a Registry and Coordinator for 
#              game Quests, tracking active objectives and global progression.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Isolates quest registry 
#   and progression rules from presentation rendering or filesystem I/O.
# - Open-Closed Principle (OCP): Implements an extensible data-driven Resource 
#   Hotspot Registry. The hardcoded match tables are completely replaced by a 
#   dynamic mapping lookup, closing this class to modifications when adding new 
#   resource types or quest categories.
# ==============================================================================
class_name QuestService
extends RefCounted

## Dynamic database mapping Quest IDs (String) to Quest resources.
static var _quests: Dictionary = {}

## The currently active quest being tracked by the player.
static var _active_quest: Quest

## Dynamic registry mapping Item IDs (int) to geographic Vector3 hotspot coordinates.
## Enables OCP-compliant quest routing for gathering or mining tasks.
static var _resource_hotspots: Dictionary = {}


## Static Constructor: Registers default base-game resource coordinates on boot.
static func _static_init() -> void:
	# Default coordinates pointing to natural resource concentrations (Hotspots)
	var craggy_mines_stone := Vector3(-150.0, 15.0, -150.0) # Peaks: Stone, Coal
	var steves_cabin_fields := Vector3(300.0, 11.5, -300.0) # Steve's Settlement: Crops, Wood
	var bay_of_sails_water := Vector3(0.0, 6.0, 0.0)        # Spawn Ocean: Water, Sand
	var nether_portal_lava := Vector3(-300.0, 9.5, -300.0)  # Volcanic Outpost: Lava
	
	# Register base game item hotspots polimorphically
	register_resource_hotspot(0, craggy_mines_stone)  # Stone (Generic proxy)
	register_resource_hotspot(1, craggy_mines_stone)  # Stone Block
	register_resource_hotspot(2, steves_cabin_fields) # Dirt Block
	register_resource_hotspot(4, steves_cabin_fields) # Wood Log
	register_resource_hotspot(5, steves_cabin_fields) # Shrubbery Leaves
	register_resource_hotspot(6, bay_of_sails_water)  # Translucent Water
	register_resource_hotspot(7, bay_of_sails_water)  # Fine Sand
	register_resource_hotspot(15, nether_portal_lava) # Volatile Lava
	register_resource_hotspot(18, steves_cabin_fields) # Crop Seeds
	register_resource_hotspot(20, steves_cabin_fields) # Mature Wheat Grains
	register_resource_hotspot(21, craggy_mines_stone)  # Deep Coal Ore


## Public OCP Extension API: Registers a custom coordinate target for an item ID.
## Can be called from custom biomes, structures, mods, or DLC loaders on startup.
static func register_resource_hotspot(item_id: int, target_position: Vector3) -> void:
	_resource_hotspots[item_id] = target_position
	print("[QuestService] Registered dynamic OCP hotspot for Item ID %d at %s" % [item_id, target_position])


## Registers a quest into the system database.
static func register_quest(quest: Quest) -> void:
	if quest != null and quest.quest_id != "":
		_quests[quest.quest_id] = quest


## Returns a registered quest by its ID.
static func get_quest(quest_id: String) -> Quest:
	return _quests.get(quest_id) as Quest


## Sets the currently active quest, updates its status, and maps resource targets.
static func set_active_quest(quest_id: String, player_pos: Vector3 = Vector3.ZERO) -> void:
	if _quests.has(quest_id):
		var quest: Quest = _quests[quest_id]
		if quest.status != Quest.Status.COMPLETED:
			_active_quest = quest
			_active_quest.status = Quest.Status.ACTIVE
			
			# Dynamic Resource Routing: Map coordinates to resource hotspots if applicable
			_update_gathering_target_position(_active_quest, player_pos)
			print("[QuestService] Active Quest changed to: ", _active_quest.title)


## Returns the currently tracked active quest (null if none).
static func get_active_quest() -> Quest:
	return _active_quest


## Clears the active quest track (Used when loading a fully completed campaign save).
static func clear_active_quest() -> void:
	_active_quest = null
	print("[QuestService] Active quest cleared (Campaign previously completed).")


## Marks the active quest as completed, grants rewards, and chains the next one.
static func complete_active_quest(player_node: CharacterBody3D = null) -> void:
	if _active_quest != null:
		_active_quest.status = Quest.Status.COMPLETED
		print("[QuestService] Active Quest successfully completed: ", _active_quest.title)
		
		# Grant inventory rewards safely if the player instance is provided
		if player_node != null and _active_quest.reward_item_index >= 0:
			var inv: IInventory = player_node.get("inventory") as IInventory
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


## Evaluates the active gathering quest requirements and dynamically sets the 
## target position pointing directly to the registered natural resource hotspot.
static func _update_gathering_target_position(quest: Quest, _player_pos: Vector3) -> void:
	if quest == null or quest.required_item_index == -1:
		return
		
	# OCP RESOLUTION: Look up the coordinate dynamically from the registered hotspots.
	# Completely removes hardcoded item IDs and coordinate vectors from the method body.
	if _resource_hotspots.has(quest.required_item_index):
		var registered_target: Vector3 = _resource_hotspots[quest.required_item_index]
		quest.target_position = registered_target
		print("[QuestService] Dynamically mapped target position for '%s' to registered hotspot: %s" % [quest.quest_id, registered_target])
	else:
		push_warning("[QuestService WARNING] No registered hotspot found for required Item ID: %d" % quest.required_item_index)
