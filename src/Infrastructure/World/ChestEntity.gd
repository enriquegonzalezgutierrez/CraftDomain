# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure World Prop representing an interactive 3D loot chest.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                physical loading of the chest asset, colliders, and animation.
#              - Dependency Inversion Principle (DIP): Communicates strictly 
#                through the `IInventory` abstract interface using Item IDs.
#              - OBSERVER PATTERN: Removed manual HUD synchronizations. UI updates 
#                are now driven reactively by the domain.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/ChestEntity.gd
# ==============================================================================
class_name ChestEntity
extends StaticBody3D

const MODEL_PATH := "res://assets/models/decorations/chest.glb"

# ==============================================================================
# MATHEMATICAL ALIGNMENT CONSTANTS (Extracted from Python GLB Analyzer)
# ==============================================================================
const VERTICAL_OFFSET: float = 0.373  # Elevates center-pivot model perfectly to ground level

# Internal model instance reference
var _model_node: Node3D


func _ready() -> void:
	name = "Prop_CHEST"
	_setup_model()
	_setup_collision()


## Programmatically loads, instantiates and configures the GLB model.
func _setup_model() -> void:
	var model_scene := load(MODEL_PATH) as PackedScene
	if model_scene != null:
		_model_node = model_scene.instantiate() as Node3D
		add_child(_model_node)
		
		# Center and adjust scale based on telemetry
		_model_node.position = Vector3(0.0, VERTICAL_OFFSET, 0.0)
		_model_node.scale = Vector3(1.0, 1.0, 1.0)
	else:
		push_error("[ChestEntity] Failed to load GLB model at path: " + MODEL_PATH)
		# Fallback: Create a simple placeholder colored box if the asset is corrupt
		var mesh_instance := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.8, 0.8, 0.8)
		mesh_instance.mesh = box_mesh
		mesh_instance.position = Vector3(0.0, 0.4, 0.0)
		var mat := ORMMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.3, 0.15) # Oak brown fallback
		mesh_instance.material_override = mat
		add_child(mesh_instance)


## Generates the physical collision box for highlighting and raycast detection.
func _setup_collision() -> void:
	var col_shape := CollisionShape3D.new()
	col_shape.name = "ChestCollider"
	
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.85, 0.85, 0.85)
	
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 0.425, 0.0) # Ground level offset
	add_child(col_shape)


## Public Interaction API: Triggered when player aims and clicks right mouse button.
func interact(player_node: CharacterBody3D) -> void:
	var inventory := player_node.get("inventory") as IInventory
	var hud := player_node.get("hud") as PlayerHUD
	
	if is_instance_valid(inventory):
		# Roll a random reward: 50% chance for food (ID 16), 50% for lava fuel (ID 15)
		var reward_item_id := 16 if randf() > 0.5 else 15
		
		# Symmetrically fetch the correct translation description key (i18n compliance)
		var desc_key := "NOTIFICATION_LOOT_FOUND_DESC_CHICKEN" if reward_item_id == 16 else "NOTIFICATION_LOOT_FOUND_DESC_LAVA"
		
		# Grant the physical reward using the clean DIP interface method
		inventory.add_item(reward_item_id, 1)
		
		# Increment active quest progression on chest open if applicable
		var active_q := QuestService.get_active_quest()
		if active_q != null and active_q.required_item_index == reward_item_id:
			active_q.progress_counter = min(active_q.required_quantity, active_q.progress_counter + 1)
		
		# Trigger sliding toast notification with localized keys
		if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
			hud.call("show_quest_notification", "NOTIFICATION_LOOT_FOUND_HEADER", desc_key)
			
		# Disable collider immediately to prevent double-interactions during animation
		var collider := get_node_or_null("ChestCollider")
		if is_instance_valid(collider):
			collider.queue_free()
			
		# Play a satisfying scaling pop animation before self-deleting
		var pop_tween := create_tween()
		pop_tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(self, "scale", Vector3(0.0, 0.0, 0.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		pop_tween.tween_callback(queue_free)
