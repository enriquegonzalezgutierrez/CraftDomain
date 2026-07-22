# ==============================================================================
# Pathfile: res://src/Domain/Quest/QuestService.gd
# Description: Pure Domain Service managing quest registrations, active progression,
#              reward distributions, and campaign chaining via domain signals.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name QuestService
extends RefCounted

signal active_quest_changed(new_quest: Quest)

static var instance: QuestService = null
static var _quests: Dictionary = {}
static var _active_quest: Quest
static var _resource_hotspots: Dictionary = {}
static var _initialized: bool = false


func _init() -> void:
	instance = self


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	if instance == null:
		instance = QuestService.new()
	_register_default_resource_hotspots()


static func _register_default_resource_hotspots() -> void:
	var craggy_mines_stone := Vector3(-150.0, 15.0, -150.0)
	var steves_cabin_merchant := Vector3(302.5, 11.0, -297.5) # Exact Merchant position in Steve's Cabin!
	var bay_of_sails_water := Vector3(0.0, 6.0, 0.0)
	var nether_portal_lava := Vector3(-300.0, 9.5, -300.0)
	
	register_resource_hotspot(0, craggy_mines_stone)
	register_resource_hotspot(1, craggy_mines_stone)
	register_resource_hotspot(2, steves_cabin_merchant)
	register_resource_hotspot(4, steves_cabin_merchant)
	register_resource_hotspot(5, steves_cabin_merchant)
	register_resource_hotspot(6, bay_of_sails_water)
	register_resource_hotspot(7, bay_of_sails_water)
	register_resource_hotspot(15, nether_portal_lava)
	register_resource_hotspot(18, steves_cabin_merchant)
	register_resource_hotspot(20, steves_cabin_merchant)
	register_resource_hotspot(21, craggy_mines_stone)


static func register_resource_hotspot(item_id: int, target_position: Vector3) -> void:
	_resource_hotspots[item_id] = target_position


static func register_quest(quest: Quest) -> void:
	if quest != null and quest.quest_id != "":
		_quests[quest.quest_id] = quest


static func get_quest(quest_id: String) -> Quest:
	return _quests.get(quest_id) as Quest


static func set_active_quest(quest_id: String, player_pos: Vector3 = Vector3.ZERO) -> void:
	_ensure_initialized()
	if _quests.has(quest_id):
		var quest: Quest = _quests[quest_id]
		if quest.status != Quest.Status.COMPLETED:
			_active_quest = quest
			_active_quest.status = Quest.Status.ACTIVE
			_update_gathering_target_position(_active_quest, player_pos)
			_notify_quest_changed()


static func get_active_quest() -> Quest:
	return _active_quest


static func clear_active_quest() -> void:
	_active_quest = null
	_notify_quest_changed()


static func complete_active_quest(player_node: Object = null) -> void:
	if _active_quest == null:
		return
		
	_active_quest.status = Quest.Status.COMPLETED
	_grant_quest_rewards(player_node)
	
	var next_id := _active_quest.next_quest_id
	_active_quest = null
	
	if next_id != "":
		var p_pos: Vector3 = player_node.get("global_position") if is_instance_valid(player_node) else Vector3.ZERO
		set_active_quest(next_id, p_pos)
	else:
		_notify_quest_changed()


static func _grant_quest_rewards(player_node: Object) -> void:
	if is_instance_valid(player_node) and _active_quest.reward_item_index >= 0:
		var inv: IInventory = player_node.get("inventory") as IInventory
		if is_instance_valid(inv):
			var _success := inv.add_item(_active_quest.reward_item_index, _active_quest.reward_quantity)


static func _update_gathering_target_position(quest: Quest, _player_pos: Vector3) -> void:
	if quest == null:
		return
		
	# Steve's Cabin merchant quest location override
	if quest.quest_id == "fuel_fryer":
		quest.target_position = Vector3(302.5, 11.0, -297.5)
		return
		
	if quest.required_item_index >= 0 and _resource_hotspots.has(quest.required_item_index):
		quest.target_position = _resource_hotspots[quest.required_item_index] as Vector3


static func _notify_quest_changed() -> void:
	if is_instance_valid(instance):
		instance.active_quest_changed.emit(_active_quest)
