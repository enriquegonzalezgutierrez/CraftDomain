# ==============================================================================
# Pathfile: res://src/Infrastructure/World/WishingWellEntity.gd
# Description: Infrastructure Static Entity representing an interactive Wishing Well.
#              Manages collision setups and interactive coin-stone toss transactions.
#              SOLID CLEANUP: Purged all procedural mesh generation from code (Section 7.6).
#              All visual nodes are declared in .tscn. Decomposed into cohesive sub-methods.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WishingWellEntity
extends StaticBody3D

const COIN_STONE_ITEM_ID: int = 1


func _ready() -> void:
	name = "Prop_WISHING_WELL"


## Interaction Router: Manages inventory checks and routes to sub-methods (SRP)
func interact(player_node: CharacterBody3D) -> void:
	if not is_instance_valid(player_node):
		return
		
	var inventory := player_node.get("inventory") as IInventory
	var hud := player_node.get("hud") as PlayerHUD
	
	if is_instance_valid(inventory):
		# Stone Block (ID 1) acts as our copper coin token proxy
		if inventory.get_item_total_quantity(COIN_STONE_ITEM_ID) >= 1:
			_execute_wish_transaction(inventory, hud)
		else:
			_display_well_instructions(hud)


func _execute_wish_transaction(inventory: IInventory, hud: PlayerHUD) -> void:
	inventory.consume_item(COIN_STONE_ITEM_ID, 1)
	
	AudioService.play_sfx_static("loot_pickup", global_position)
	AudioService.play_sfx_static("block_break", global_position)
	
	# Roll random reward: Chicken (16), Diamond Ore (28), or Glowstone (30)
	var rewards_pool: Array[int] = [16, 28, 30] 
	var rolled_item_id := rewards_pool[randi() % rewards_pool.size()]
	inventory.add_item(rolled_item_id, 1)
	
	_update_active_gathering_quest_progress(rolled_item_id)
	_display_wish_success_toast(hud, rolled_item_id)


func _update_active_gathering_quest_progress(rolled_item_id: int) -> void:
	var active_q := QuestService.get_active_quest() as Quest
	if active_q != null and active_q.required_item_index == rolled_item_id:
		active_q.progress_counter = min(active_q.required_quantity, active_q.progress_counter + 1)


func _display_wish_success_toast(hud: PlayerHUD, rolled_item_id: int) -> void:
	if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
		var reward_name := InventoryComponent.get_item_name_by_id(rolled_item_id)
		hud.call(
			"show_quest_notification", 
			tr("NOTIFICATION_WISH_GRANTED_HEADER"), 
			tr("NOTIFICATION_RECEIVED_PREFIX") + " 1x " + reward_name.to_upper()
		)


func _display_well_instructions(hud: PlayerHUD) -> void:
	if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
		hud.call(
			"show_quest_notification", 
			tr("NOTIFICATION_WISHING_WELL_HEADER"), 
			tr("NOTIFICATION_WISHING_WELL_DESC")
		)
		AudioService.play_sfx_static("npc_chat", global_position)
