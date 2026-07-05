# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive colossal Elephant.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision, gravity, and lifecycle contracts.
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                to the sub-component, and physics movements to the base class.
#              - Dependency Inversion Principle (DIP): Automatically prunes 
#                extraneous Blender-exported nodes (Cameras, Lights) on initialization.
# MATHEMATICAL CALIBRATION (V5 Telemetry):
#              - Total model height is 1.051m. Scaled by 3.0012x to achieve a 
#                colossal giant height of ~3.5m.
#              - Model origin is centered. Raised the model Y-position by +1.7500m 
#                to anchor its heavy feet flat on the physical voxel colliders.
#              - Corrected the sideways orientation mesh bug by setting the 
#                Y-axis rotation offset to -90 degrees.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/ElephantEntity.gd
# ==============================================================================
class_name ElephantEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/elephant.glb"


func _init(spawn_pos: Vector3) -> void:
	# Elephants spawn with 10 Hearts of health (20 HP) due to their colossal size
	super(spawn_pos, 20)
	name = "Entity_ELEPHANT"


## Loads the external GLB model and hooks it into the procedural bobbing skeleton
func _build_visual_representation() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var model_scene := load(MODEL_PATH) as PackedScene
		var model_node := model_scene.instantiate() as Node3D
		
		# Prune Blender's default light and camera nodes to prevent rendering conflicts
		_prune_extraneous_nodes(model_node)
		
		# ======================================================================
		# MATHEMATICAL CALIBRATION (Based on GLB Analyzer V5)
		# ======================================================================
		# 1. Scale model by 3.0012x to achieve a towering height of ~3.5m
		model_node.scale = Vector3(3.0012, 3.0012, 3.0012)
		
		# 2. Origin is centered. Raise Y by +1.7500m to anchor the feet
		#    perfectly flat on the ground plane
		model_node.position = Vector3(0.0, 1.7500, 0.0)
		
		# 3. Apply -90-degree visual offset to correct the sideways orientation bug
		model_node.rotation_degrees = Vector3(0, -90, 0)
		# ======================================================================
		
		# Append the model to the bob joint to automatically inherit walk animations
		visual_component.body_bob_node.add_child(model_node)
		_register_glb_materials(model_node)
	else:
		push_error("[ElephantEntity] GLB model not found at path: " + MODEL_PATH)


## Recursively duplicates materials to prevent material-sharing leaks
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		# EXPLICIT CASTING: Prevents static analyzer type inference errors
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
	for i in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		if "Camera" in child.name or "Light" in child.name:
			child.free()
		else:
			_prune_extraneous_nodes(child)


## Calibrated to the scaled bounding box size (3.5m height, 4.0m depth, 3.3m width after rotation)
func _get_collision_box_size() -> Vector3:
	return Vector3(3.30, 3.50, 4.00)


## Centered relative to the colossal height
func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 1.575, 0.0)


## Flag used by the animation ticker to configure bouncy walks (Disabled for quadrupeds/elephants)
func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


func _on_domain_entity_took_damage(_amount: int) -> void:
	# Elephant panic escape velocity (slightly lower jump due to high body mass)
	velocity.y = JUMP_VELOCITY * 0.75
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)


## Drops 1x Fried Chicken (Meat proxy) on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	inv.add_item(16, 1)
