# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing an aquatic Sea Turtle.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision, gravity, and lifecycle contracts.
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                to the sub-component, and physics movements to the base class.
#              - Dependency Inversion Principle (DIP): Automatically prunes 
#                extraneous Blender-exported nodes (Cameras, Lights) on initialization.
# MATHEMATICAL CALIBRATION:
#              - Total model height is 6.137m. Scaled by 0.0570x to achieve a 
#                realistic aquatic turtle height of ~0.35m.
#              - Fixed floating bug: Lowered model Y-position back to 0.0.
#              - Corrected the Z-Asymmetry (5.640 ratio) pivot bug by setting the 
#                Y-axis rotation offset to 180 degrees.
# WARNING RESOLUTION:
#              - Injected material property overrides in `_register_glb_materials` 
#                to force-disable normal maps and anisotropy. This completely suppresses 
#                the "shader requires tangents" error from GLBs exported without them.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/TurtleEntity.gd
# ==============================================================================
class_name TurtleEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/turtle.glb"


func _init(spawn_pos: Vector3) -> void:
	# Turtles spawn with 2 Hearts of health (4 HP)
	super(spawn_pos, 4)
	name = "Entity_TURTLE"


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
		# 1. Scale model by 0.0570x to reduce height to ~0.35m
		model_node.scale = Vector3(0.0570, 0.0570, 0.0570)
		
		# 2. Origin fix: Anchored to 0.0 so the flippers sit flat on the ground plane
		model_node.position = Vector3(0.0, 0.0, 0.0)
		
		# 3. Corrected orientation to face forward (-Z)
		model_node.rotation_degrees = Vector3(0, 180, 0)
		# ======================================================================
		
		# Append the model to the bob joint to automatically inherit animations
		visual_component.body_bob_node.add_child(model_node)
		_register_glb_materials(model_node)
	else:
		push_error("[TurtleEntity] GLB model not found at path: " + MODEL_PATH)


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


## Calibrated to the scaled bounding box size (0.35m height, 0.63m depth)
func _get_collision_box_size() -> Vector3:
	return Vector3(0.30, 0.35, 0.65)


## Centered relative to the shell height
func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.175, 0.0)


## Flag used by the animation ticker to configure bouncy walks (Disabled to allow smooth gliding)
func _is_avian() -> bool:
	return true


func _can_socialize() -> bool:
	return true


func _on_domain_entity_took_damage(_amount: int) -> void:
	# Turtle panic escape velocity
	velocity.y = JUMP_VELOCITY
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)


## Drops 1x Sand Block on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 7: Sand Block
	inv.add_item(7, 1)
