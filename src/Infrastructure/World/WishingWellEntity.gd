# ==============================================================================
# Pathfile: res://src/Infrastructure/World/WishingWellEntity.gd
# Description: Infrastructure Static Entity representing an interactive Wishing Well.
#              Manages collision setups and interactive coin toss transactions.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WishingWellEntity
extends StaticBody3D

const MODEL_PATH: String = "res://assets/models/decorations/wishing_well_odyssey.glb"


func _ready() -> void:
	name = "Prop_WISHING_WELL"
	
	# Locate and sanitize the static GLB model pre-instanced in the .tscn scene tree
	var model_node := get_node_or_null("Visuals/BodyBobJoint/wishing_well") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)


func interact(player_node: CharacterBody3D) -> void:
	if not is_instance_valid(player_node):
		return
		
	var inventory := player_node.get("inventory") as IInventory
	var hud := player_node.get("hud") as PlayerHUD
	
	if is_instance_valid(inventory):
		# Stone Block (ID 1) acts as our copper coin token proxy
		var cost_item_id := 1
		var cost_qty := 1
		
		if inventory.get_item_total_quantity(cost_item_id) >= cost_qty:
			# 1. Deduct the cost
			inventory.consume_item(cost_item_id, cost_qty)
			
			# 2. Play coin clink and water splash spatial SFX (Service Locator)
			AudioService.play_sfx_static("loot_pickup", global_position)
			AudioService.play_sfx_static("block_break", global_position)
			
			# 3. Roll a random wish reward (Diamond Ore, Glowstone, or Fried Chicken!)
			var rewards_pool: Array[int] = [16, 28, 30] # Chicken (16), Diamond (28), Glowstone (30)
			var rolled_item_id := rewards_pool[randi() % rewards_pool.size()]
			inventory.add_item(rolled_item_id, 1)
			
			# Symmetrically fetch localized name binding
			var reward_name := ""
			if rolled_item_id == 16: reward_name = tr("ITEM_FRIED_CHICKEN")
			elif rolled_item_id == 28: reward_name = tr("BLOCK_DIAMOND_ORE")
			else: reward_name = tr("BLOCK_GLOWSTONE")
			
			# 4. Display a gold toast notification on the player's HUD
			if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
				hud.call(
					"show_quest_notification", 
					tr("NOTIFICATION_WISH_GRANTED_HEADER"), 
					tr("NOTIFICATION_RECEIVED_PREFIX") + " 1x " + reward_name.to_upper()
				)
		else:
			# If the player has no stone coin, flash a localized helpful tip
			if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
				hud.call(
					"show_quest_notification", 
					tr("NOTIFICATION_WISHING_WELL_HEADER"), 
					tr("NOTIFICATION_WISHING_WELL_DESC")
				)
				AudioService.play_sfx_static("npc_chat", global_position)


func _create_box(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_pos
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
