# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive chicken/duck.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision and lifecycle contracts.
#              - Single Responsibility Principle (SRP): Delegates procedural physics 
#                to the base class, and visual mesh manipulation to the sub-component.
#              - Dependency Inversion Principle (DIP): Automatically prunes 
#                extraneous Blender-exported nodes (Cameras, Lights) on initialization.
# MATHEMATICAL CALIBRATION:
#              - Original model height is tiny (0.075m). Scaled UP by 4.6922x to 
#                bring it to a realistic avian height of ~0.35m.
#              - Model origin is already at 0.0. No Y-offset needed.
#              - Applied 180-degree Y rotation.
# WARNING RESOLUTION:
#              - Injected material property overrides in `_register_glb_materials` 
#                to force-disable normal maps and anisotropy.
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
		# 1. Scale model UP by 4.6922x to increase height from 0.075m to ~0.35m
		model_node.scale = Vector3(4.6922, 4.6922, 4.6922)
		
		# 2. Origin fix: Anchored to 0.0 so the feet sit flat on the ground plane
		model_node.position = Vector3(0.0, 0.0, 0.0)
		
		# 3. Apply 180-degree visual offset to correct orientation
		model_node.rotation_degrees = Vector3(0, 180, 0)
		# ======================================================================
		
		# Append the model to the bob joint to automatically inherit walk animations
		visual_component.body_bob_node.add_child(model_node)
		_register_glb_materials(model_node)
	else:
		push_error("[ChickenEntity] GLB model not found at path: " + MODEL_PATH)


## Recursively duplicates materials and patches tangent warnings
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: Material = node.get_active_material(0) as Material
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0) as Material
			
		if mat is BaseMaterial3D:
			var new_mat := mat.duplicate() as BaseMaterial3D
			
			# Shading Fix: Prevent the material from being too dark
			new_mat.roughness = 0.85
			new_mat.metallic = 0.0
			
			# TANGENT WARNING SHIELD
			new_mat.normal_enabled = false
			new_mat.anisotropy_enabled = false
			new_mat.clearcoat_enabled = false
			new_mat.heightmap_enabled = false
			
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
