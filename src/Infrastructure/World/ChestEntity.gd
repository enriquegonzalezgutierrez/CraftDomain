# ==============================================================================
# Pathfile: res://src/Infrastructure/World/ChestEntity.gd
# Description: Infrastructure Static Entity representing an interactive 3D loot chest.
#              Delegates model and material sanitization to GLBModelSanitizer (DRY).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChestEntity
extends StaticBody3D

const MODEL_PATH: String = "res://assets/models/decorations/chest.glb"
const VERTICAL_OFFSET: float = 0.373  

var _model_node: Node3D


func _ready() -> void:
	name = "Prop_CHEST"
	_setup_model()
	_setup_collision()


func _setup_model() -> void:
	var model_scene := load(MODEL_PATH) as PackedScene
	if model_scene != null:
		_model_node = model_scene.instantiate() as Node3D
		add_child(_model_node)
		
		_model_node.position = Vector3(0.0, VERTICAL_OFFSET, 0.0)
		_model_node.scale = Vector3(1.0, 1.0, 1.0)
		
		# Centralized OCP/DRY Cleanup
		GLBModelSanitizer.sanitize_model(_model_node)
	else:
		push_error("[ChestEntity] Failed to load GLB model at path: " + MODEL_PATH)
		_setup_fallback_mesh()


func _setup_fallback_mesh() -> void:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.8, 0.8, 0.8)
	mesh_instance.mesh = box_mesh
	mesh_instance.position = Vector3(0.0, 0.4, 0.0)
	var mat := ORMMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.3, 0.15) 
	mesh_instance.material_override = mat
	add_child(mesh_instance)


func _setup_collision() -> void:
	var col_shape := CollisionShape3D.new()
	col_shape.name = "ChestCollider"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.85, 0.85, 0.85)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 0.425, 0.0) 
	add_child(col_shape)


func interact(player_node: CharacterBody3D) -> void:
	var inventory := player_node.get("inventory") as IInventory
	var hud := player_node.get("hud") as PlayerHUD
	
	if is_instance_valid(inventory):
		var reward_item_id := 16 if randf() > 0.5 else 15
		var desc_key := "NOTIFICATION_LOOT_FOUND_DESC_CHICKEN" if reward_item_id == 16 else "NOTIFICATION_LOOT_FOUND_DESC_LAVA"
		
		AudioService.play_sfx_static("chest_open", global_position)
		AudioService.play_sfx_static("loot_pickup")
		
		inventory.add_item(reward_item_id, 1)
		
		var active_q := QuestService.get_active_quest()
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
