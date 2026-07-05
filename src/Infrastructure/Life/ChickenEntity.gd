# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive chicken/duck.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision and lifecycle contracts.
#              - Single Responsibility Principle (SRP): Delegates procedural physics 
#                to the base class, and visual mesh manipulation to the sub-component.
#              - Dependency Inversion Principle (DIP): Automatically prunes 
#                extraneous Blender-exported nodes (Cameras, Lights) on initialization 
#                to protect global rendering pipelines.
# MATHEMATICAL CALIBRATION:
#              - Original model height is 10.94m (Giant). Scaled by 0.06x to 
#                bring it down to a realistic avian height of ~0.65m.
#              - Model origin is centered. Min Y is -5.44m. After scaling, the 
#                feet sit at -0.326m. Raised position.y by +0.326m to keep the 
#                feet flat on the ground plane.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/ChickenEntity.gd
# ==============================================================================
class_name ChickenEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/chicken.glb"


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1) # 1 Heart of health (2 HP)
	name = "Entity_CHICKEN"


## Loads the external GLB model and hooks it into the procedural bobbing skeleton
func _build_visual_representation() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var model_scene := load(MODEL_PATH) as PackedScene
		var model_node := model_scene.instantiate() as Node3D
		
		# Prune Blender's default light and camera nodes to prevent rendering conflicts
		_prune_extraneous_nodes(model_node)
		
		# ======================================================================
		# MATHEMATICAL CALIBRATION (Based on GLB Analyzer)
		# ======================================================================
		# 1. Scale model by 0.06x to reduce height from 10.94m to ~0.65m
		model_node.scale = Vector3(0.06, 0.06, 0.06)
		
		# 2. Offset Y by +0.326m to align the scaled bottom vertices (at -0.326m)
		#    perfectly flat on top of the physical voxel colliders
		model_node.position = Vector3(0.0, 0.326, 0.0)
		
		# model_node.rotation_degrees = Vector3(0, 180, 0) # Uncomment if walking backwards
		# ======================================================================
		
		# Append the model to the bob joint to automatically inherit walk animations
		visual_component.body_bob_node.add_child(model_node)
		_register_glb_materials(model_node)
	else:
		push_error("[ChickenEntity] GLB model not found at path: " + MODEL_PATH)


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


## Recursively locates and frees extraneous camera and light nodes
func _prune_extraneous_nodes(node: Node) -> void:
	# Iterate in reverse order to safely delete nodes while looping
	for i in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		if "Camera" in child.name or "Light" in child.name:
			child.free() # Safely eliminate the node instantly
		else:
			_prune_extraneous_nodes(child)


func _get_collision_box_size() -> Vector3:
	return Vector3(0.46, 0.69, 0.46)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)


## Flag used by the animation ticker to configure bouncy avian walks
func _is_avian() -> bool:
	return true


func _can_socialize() -> bool:
	return true


func _on_domain_entity_took_damage(_amount: int) -> void:
	# Avian panic bounce velocity
	velocity.y = JUMP_VELOCITY
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)


## Drops 1x Fried Chicken on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	inv.add_item(16, 1)
