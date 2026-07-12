# ==============================================================================
# Pathfile: res://src/Infrastructure/World/ChestEntity.gd
# Description: Infrastructure Static Entity representing an interactive 3D loot chest.
#              Manages collision setups, item looting, and custom popup animations.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChestEntity
extends StaticBody3D

const MODEL_PATH: String = "res://assets/models/decorations/chest.glb"


func _ready() -> void:
	name = "Prop_CHEST"
	
	# Locate and sanitize the static GLB model pre-instanced in the .tscn scene tree
	var model_node := get_node_or_null("Visuals/BodyBobJoint/chest") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)


func interact(player_node: CharacterBody3D) -> void:
	var inventory := player_node.get("inventory") as IInventory
	var hud := player_node.get("hud") as PlayerHUD
	
	if is_instance_valid(inventory):
		var reward_item_id := 16 if randf() > 0.5 else 15
		var desc_key := "NOTIFICATION_LOOT_FOUND_DESC_CHICKEN" if reward_item_id == 16 else "NOTIFICATION_LOOT_FOUND_DESC_LAVA"
		
		AudioService.play_sfx_static("chest_open", global_position)
		AudioService.play_sfx_static("loot_pickup")
		
		inventory.add_item(reward_item_id, 1)
		
		var active_q := QuestService.get_active_quest() as Quest
		if active_q != null and active_q.required_item_index == reward_item_id:
			active_q.progress_counter = min(active_q.required_quantity, active_q.progress_counter + 1)
		
		if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
			hud.call("show_quest_notification", "NOTIFICATION_LOOT_FOUND_HEADER", desc_key)
			
		var collider := get_node_or_null("ChestCollider")
		if is_instance_valid(collider):
			collider.queue_free()
			
		var pop_tween := create_tween()
		pop_tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(self, "scale", Vector3(0.0, 0.0, 0.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		pop_tween.tween_callback(queue_free)
