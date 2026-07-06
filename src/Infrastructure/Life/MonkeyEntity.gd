# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive forest Monkey.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision, gravity, and lifecycle contracts.
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                to the sub-component, and physics movements to the base class.
#              - Dependency Inversion Principle (DIP): Automatically prunes 
#                extraneous Blender-exported nodes (Cameras, Lights) on initialization.
# MATHEMATICAL CALIBRATION (Blender Z-Up Axis Fix):
#              - Model contains a baked 90-degree X-rotation. The TRUE vertical height 
#                is its raw Z-axis (1.075m), not its Y-axis (0.601m).
#              - Scaled by 0.6976x to achieve a realistic forest monkey height of ~0.75m.
#              - Max Z-vertex is 0.0. When rotated 90 degrees, the feet sit perfectly 
#                at Y = 0.0. No vertical Y-offset is needed!
#              - Corrected the bipedal alignment by setting the Y-axis rotation 
#                offset to 180 degrees.
# WARNING RESOLUTION:
#              - Injected material property overrides in `_register_glb_materials` 
#                to force-disable normal maps and anisotropy.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MonkeyEntity.gd
# ==============================================================================
class_name MonkeyEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/monkey.glb"


func _init(spawn_pos: Vector3) -> void:
	# Monkeys spawn with 3 Hearts of health (6 HP)
	super(spawn_pos, 6)
	name = "Entity_MONKEY"


## Loads the external GLB model and hooks it into the procedural bobbing skeleton
func _build_visual_representation() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var model_scene := load(MODEL_PATH) as PackedScene
		var model_node := model_scene.instantiate() as Node3D
		
		# Prune Blender's default light and camera nodes to prevent rendering conflicts
		_prune_extraneous_nodes(model_node)
		
		# ======================================================================
		# MATHEMATICAL CALIBRATION (Cross-Axis Fix)
		# ======================================================================
		# 1. Scale model by 0.6976x (Target: 0.75m / Actual Z-Depth: 1.075m)
		model_node.scale = Vector3(0.6976, 0.6976, 0.6976)
		
		# 2. Z-Axis max was 0.0. With X=90 rotation, feet are perfectly at 0.0.
		model_node.position = Vector3(0.0, 0.0, 0.0)
		
		# 3. Apply 180-degree visual offset to correct the backwards-walk orientation
		model_node.rotation_degrees = Vector3(0, 180, 0)
		# ======================================================================
		
		# Append the model to the bob joint to automatically inherit walk animations
		visual_component.body_bob_node.add_child(model_node)
		_register_glb_materials(model_node)
	else:
		push_error("[MonkeyEntity] GLB model not found at path: " + MODEL_PATH)


## Recursively duplicates materials and patches tangent warnings
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		# EXPLICIT CASTING: Prevents static analyzer type inference errors
		var mat: Material = node.get_active_material(0) as Material
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0) as Material
			
		if mat is BaseMaterial3D:
			var new_mat := mat.duplicate() as BaseMaterial3D
			
			# ==================================================================
			# TANGENT WARNING SHIELD: Disables material properties that crash  
			# the clustered forward renderer when the mesh lacks tangent arrays.
			# ==================================================================
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


## Calibrated to the scaled bounding box size (0.75m height, 1.34m depth, 0.95m width)
func _get_collision_box_size() -> Vector3:
	return Vector3(0.95, 0.75, 1.34)


## Centered relative to the body height
func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.375, 0.0)


## Flag used by the animation ticker to configure bouncy walks (Disabled for quadrupeds/climbers)
func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


func _on_domain_entity_took_damage(_amount: int) -> void:
	# Monkey panic escape velocity
	velocity.y = JUMP_VELOCITY
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)


## Drops 1x Fried Chicken (Meat proxy) on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	inv.add_item(16, 1)
