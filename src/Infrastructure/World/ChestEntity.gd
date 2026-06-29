# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure World Prop representing an interactive 3D loot chest.
#              SOLID COMPLIANCE: Adheres to the Single Responsibility Principle (SRP)
#              by handling only the physical instantiation, collision box setup,
#              and interaction/loot granting logic of the chest asset.
#              AI QUEST UPGRADE: Safely increments the active quest's incremental 
#              progress_counter when looting chest reward items.
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

## Programmatically loads, instantiates and configures the GLB model
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

## Generates the physical collision box for highlighting and raycast detection
func _setup_collision() -> void:
	var col_shape := CollisionShape3D.new()
	col_shape.name = "ChestCollider"
	
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.85, 0.85, 0.85)
	
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 0.425, 0.0) # Ground level offset
	add_child(col_shape)

## Public Interaction API: Triggered when player aims and clicks right mouse button
func interact(player_node: CharacterBody3D) -> void:
	var inventory = player_node.get("inventory")
	var hud = player_node.get("hud")
	
	if is_instance_valid(inventory):
		# Roll a random professional loot reward: 50% chance for food, 50% for lava fuel
		var reward_slot := 6 if randf() > 0.5 else 5
		var item_name := "Fried Chicken" if reward_slot == 6 else "Lava Bucket"
		
		# Grant the physical reward inside the inventory component
		inventory.modify_slot_quantity(reward_slot, 1)
		player_node.call("_sync_hud_counters")
		
		# ======================================================================
		# INCREMENT ACTIVE QUEST PROGRESSION ON CHEST OPEN
		# ======================================================================
		var active_q := QuestService.get_active_quest()
		if active_q != null and active_q.required_item_index == reward_slot:
			active_q.progress_counter = min(active_q.required_quantity, active_q.progress_counter + 1)
		
		# Trigger our newly created sliding toast notification
		if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
			hud.call("show_quest_notification", "Loot Found!", "You gathered 1x " + item_name + "!")
			
		# Disable collider immediately to prevent double-interactions during animation
		var collider = get_node_or_null("ChestCollider")
		if is_instance_valid(collider):
			collider.queue_free()
			
		# Play a satisfying scaling pop animation before self-deleting
		var pop_tween := create_tween()
		pop_tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(self, "scale", Vector3(0.0, 0.0, 0.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		pop_tween.tween_callback(queue_free)
