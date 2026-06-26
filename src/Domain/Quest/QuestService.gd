# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Service acting as a Registry and Coordinator for 
#              game Quests, tracking active objectives and global progression.
#              SOLID COMPLIANCE: Stripped of hardcoded registries (SRP). Now 
#              autonomously processes rewards and chain transitions (OCP).
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

## Sets the currently active quest and updates its status
static func set_active_quest(quest_id: String) -> void:
	if _quests.has(quest_id):
		var quest: Quest = _quests[quest_id]
		if quest.status != Quest.Status.COMPLETED:
			_active_quest = quest
			_active_quest.status = Quest.Status.ACTIVE
			print("[QuestService] Active Quest changed to: ", _active_quest.title)

## Returns the currently tracked active quest (null if none)
static func get_active_quest() -> Quest:
	return _active_quest

## Marks the active quest as completed, grants rewards, and chains the next one
## SOLID SRP: Accepts an optional player_node parameter to grant physical rewards.
## SOLID OCP: Uses next_quest_id to chain story progression dynamically.
static func complete_active_quest(player_node: CharacterBody3D = null) -> void:
	if _active_quest != null:
		_active_quest.status = Quest.Status.COMPLETED
		print("[QuestService] Active Quest successfully completed: ", _active_quest.title)
		
		# Grant inventory rewards safely if the player instance is provided
		if player_node != null and _active_quest.reward_item_index >= 0:
			var inv: IInventory = player_node.get("inventory")
			if is_instance_valid(inv):
				inv.modify_slot_quantity(_active_quest.reward_item_index, _active_quest.reward_quantity)
				player_node.call("_sync_hud_counters")
				
		# Cache the next quest link before clearing
		var next_id := _active_quest.next_quest_id
		_active_quest = null
		
		# Auto-trigger next quest in the chain
		if next_id != "":
			set_active_quest(next_id)
