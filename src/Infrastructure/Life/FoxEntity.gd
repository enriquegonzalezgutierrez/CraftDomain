# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive Fox.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision and lifecycle contracts.
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                to the sub-component, and physics movements to the base class.
# MATHEMATICAL CALIBRATION:
#              - Total model height is 1.987m. Scaled by 0.3x to achieve a 
#                realistic wildlife height of ~0.6m.
#              - Model origin is perfectly centered at the feet (Y = -0.01m).
#                No vertical offset is required (position.y = 0.0).
#              - Corrected the sideways orientation mesh bug by setting the 
#                Y-axis rotation offset to -90 degrees.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/FoxEntity.gd
# ==============================================================================
class_name FoxEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/fox.glb"


func _init(spawn_pos: Vector3) -> void:
	# Foxes spawn with 2 Hearts of health (4 HP)
	super(spawn_pos, 4)
	name = "Entity_FOX"


## Loads the external GLB model and hooks it into the procedural bobbing skeleton
func _build_visual_representation() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var model_scene := load(MODEL_PATH) as PackedScene
		var model_node := model_scene.instantiate() as Node3D
		
		# ======================================================================
		# MATHEMATICAL CALIBRATION (Based on GLB Analyzer)
		# ======================================================================
		# 1. Scale model by 0.3x to achieve a realistic height of ~0.6m
		model_node.scale = Vector3(0.3, 0.3, 0.3)
		
		# 2. Origin is already perfectly at the feet. No vertical offset needed
		model_node.position = Vector3(0.0, 0.0, 0.0)
		
		# 3. Apply -90-degree visual offset to correct the sideways orientation bug
		model_node.rotation_degrees = Vector3(0, -90, 0)
		# ======================================================================
		
		visual_component.body_bob_node.add_child(model_node)
		_register_glb_materials(model_node)
	else:
		push_error("[FoxEntity] GLB model not found at path: " + MODEL_PATH)


## Recursively duplicates materials to prevent material-sharing leaks
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: Material = node.get_active_material(0) as Material
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0) as Material
			
		if mat is BaseMaterial3D:
			var new_mat := mat.duplicate() as BaseMaterial3D
			node.material_override = new_mat
			
	for child: Node in node.get_children():
		_register_glb_materials(child)


## Calibrated to the scaled bounding box size (0.6m height, 0.65m depth)
func _get_collision_box_size() -> Vector3:
	return Vector3(0.45, 0.6, 0.65)


## Centered relative to the height
func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.3, 0.0)


## Flag used by the animation ticker to configure bouncy walks (Disabled for quadrupeds)
func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


func _on_domain_entity_took_damage(_amount: int) -> void:
	# Fox panic escape velocity
	velocity.y = JUMP_VELOCITY
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)


## Drops 1x Fried Chicken (Meat proxy) on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	inv.add_item(16, 1)
