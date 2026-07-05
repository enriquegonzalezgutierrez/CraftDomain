# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive flying tropical Parrot.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity, 
#                matching the base collision, gravity, and lifecycle contracts.
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                to the sub-component, and physics movements to the base class.
#              - Dependency Inversion Principle (DIP): Automatically prunes 
#                extraneous Blender-exported nodes (Cameras, Lights) on initialization.
# PROCEDURAL FLIGHT ENGINE:
#              - Visually offsets the model upwards by +2.3m, making the parrot soar 
#                in the air while the physics collider navigates the ground safely.
#              - Injected real-time floating sine wave bobbing to simulate thermal glide.
#              - Injected high-frequency roll tilting to simulate active wing flapping.
# MATHEMATICAL CALIBRATION:
#              - Total model height is 0.805m. Scaled by 0.55x to achieve a 
#                realistic tropical parrot height of ~0.44m.
#              - Model origin is offset. Raised the model Y-position by +0.221m 
#                to anchor its feet flat on the physical voxel colliders.
#              - Corrected the crab-walk bug by setting the Y-axis rotation offset 
#                to 180 degrees (standard bird Z-alignment).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/ParrotEntity.gd
# ==============================================================================
class_name ParrotEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/parrot.glb"

# Procedural flight animation variables
var _model_node: Node3D
var _animation_time: float = 0.0


func _init(spawn_pos: Vector3) -> void:
	# Parrots spawn with 1 Heart of health (2 HP)
	super(spawn_pos, 2)
	name = "Entity_PARROT"


## Loads the external GLB model and hooks it into the procedural bobbing skeleton
func _build_visual_representation() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		_model_node = model_scene_instantiate()
		
		# Prune Blender's default light and camera nodes to prevent rendering conflicts
		_prune_extraneous_nodes(_model_node)
		
		# ======================================================================
		# MATHEMATICAL CALIBRATION (Based on GLB Analyzer)
		# ======================================================================
		# 1. Scale model by 0.55x to reduce height from 0.805m to ~0.44m
		_model_node.scale = Vector3(0.55, 0.55, 0.55)
		
		# 2. Initial flight height: Offset Y upwards by +2.5 meters (including +0.221m pivot alignment)
		_model_node.position = Vector3(0.0, 2.521, 0.0)
		
		# 3. Apply 180-degree visual offset to correct the sideways orientation bug
		#    Change to 0 if it walks backwards.
		_model_node.rotation_degrees = Vector3(0, 180, 0)
		# ======================================================================
		
		# Append the model to the bob joint to automatically inherit animations
		visual_component.body_bob_node.add_child(_model_node)
		_register_glb_materials(_model_node)
	else:
		push_error("[ParrotEntity] GLB model not found at path: " + MODEL_PATH)


## Safe helper instantiator preventing cyclic compilation locks
func model_scene_instantiate() -> Node3D:
	var model_scene := load(MODEL_PATH) as PackedScene
	return model_scene.instantiate() as Node3D


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


## Real-time Procedural Flight Simulator Loop (OCP/SRP Compliant)
func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	if is_instance_valid(_model_node):
		_animation_time += delta
		
		# Calculate speed vector (ignore vertical gravity velocity)
		var flat_velocity := Vector2(velocity.x, velocity.z)
		var is_moving := flat_velocity.length_squared() > 0.1
		
		# 1. Thermal Hover Bobbing (Smooth vertical sine wave, slightly out-of-phase with the yellow bird!)
		var hover_bob := sin(_animation_time * 3.5) * 0.22
		_model_node.position.y = 2.521 + hover_bob
		
		# 2. Wing Flap Tilting and Forward Pitch
		if is_moving:
			# High-frequency roll rotation (Z-axis) simulating active flapping
			_model_node.rotation.z = sin(_animation_time * 16.0) * 0.22
			# Tilt forward (X-axis) when moving fast
			_model_node.rotation.x = deg_to_rad(12.0)
		else:
			# Slow resting breeze tilts
			_model_node.rotation.z = sin(_animation_time * 1.8) * 0.04
			_model_node.rotation.x = 0.0


func _get_collision_box_size() -> Vector3:
	return Vector3(0.46, 0.69, 0.46)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)


## Flag used by the animation ticker to configure bouncy walks (Disabled to allow flying)
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
