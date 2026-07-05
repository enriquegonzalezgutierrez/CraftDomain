# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive marine Octopus.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision, gravity, and lifecycle contracts.
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                to the sub-component, and physics movements to the base class.
#              - Dependency Inversion Principle (DIP): Automatically prunes 
#                extraneous Blender-exported nodes (Cameras, Lights) on initialization.
# MATHEMATICAL CALIBRATION (V5 Telemetry):
#              - Total model height is 0.405m. Scaled by 1.8525x to achieve a 
#                realistic giant ocean size of ~0.75m.
#              - Model origin is centered. Raised the model Y-position by +0.3156m 
#                to anchor the tentacles perfectly flat on the ground plane.
#              - Model is baked facing forward. No rotation offset is required.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/OctopusEntity.gd
# ==============================================================================
class_name OctopusEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/octopus.glb"


func _init(spawn_pos: Vector3) -> void:
	# Octopuses spawn with 6 Hearts of health (6 HP)
	super(spawn_pos, 6)
	name = "Entity_OCTOPUS"


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
		# 1. Scale model by 1.8525x to achieve a realistic giant ocean size of ~0.75m
		model_node.scale = Vector3(1.8525, 1.8525, 1.8525)
		
		# 2. Origin is centered. Raise it up by +0.3156m on Y
		#    to anchor the tentacles perfectly flat on the ground plane
		model_node.position = Vector3(0.0, 0.3156, 0.0)
		
		# 3. Model is naturally oriented. Rotation set to 0.
		#    Uncomment and adjust the Y value if the mesh walk vector is offset.
		model_node.rotation_degrees = Vector3(0, 0, 0)
		# ======================================================================
		
		# Append the model to the bob joint to automatically inherit animations
		visual_component.body_bob_node.add_child(model_node)
		_register_glb_materials(model_node)
	else:
		push_error("[OctopusEntity] GLB model not found at path: " + MODEL_PATH)


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


## Calibrated to the scaled bounding box size (0.75m height, 1.10m depth, 1.00m width)
func _get_collision_box_size() -> Vector3:
	return Vector3(1.0, 0.75, 1.1)


## Centered relative to the body height
func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.375, 0.0)


## Flag used by the animation ticker to configure bouncy walks (Disabled to allow smooth swimming glide)
func _is_avian() -> bool:
	return true


func _can_socialize() -> bool:
	return true


func _on_domain_entity_took_damage(_amount: int) -> void:
	# Octopus panic escape velocity
	velocity.y = JUMP_VELOCITY
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)


## Drops 1x Sand Block on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 7: Sand Block
	inv.add_item(7, 1)
