# ==============================================================================
# Project: CraftDomain
# Description: Concrete Fauna Visual Representation Strategy.
#              Loads, scales, offsets, and animates standard quadruped/wildlife GLB meshes.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                GLB scene loading, tangent warning suppression, and built-in 
#                animation player triggers.
#              - Open-Closed Principle (OCP): Fully generic. Any new wildlife model 
#                (Cat, Fox, Shark) can be configured purely by instantiating 
#                this Strategy resource with custom paths on disk.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/FaunaVisualRepresentation.gd
# ==============================================================================
class_name FaunaVisualRepresentation
extends IEntityVisualRepresentation

# Configurable paths and calibration metrics
@export var model_path: String = ""
@export var scale_multiplier: Vector3 = Vector3.ONE
@export var position_offset: Vector3 = Vector3.ZERO
@export var rotation_offset: Vector3 = Vector3.ZERO

# Physical collision parameters matched to the model height
@export var collision_size: Vector3 = Vector3(0.6, 0.8, 0.6)
@export var collision_position: Vector3 = Vector3(0.0, 0.4, 0.0)

# Baked internal animation track names (customizable per GLB export)
@export var anim_idle_name: String = "idle"
@export var anim_walk_name: String = "walk"

# Internal state tracking
var _host: CharacterBody3D
var _model_node: Node3D
var _anim_player: AnimationPlayer


## Concrete Implementation: Instantiates the GLB, prunes nodes, and configures materials
func build_representation(host: CharacterBody3D, target_parent: Node3D) -> void:
	_host = host
	
	if not FileAccess.file_exists(model_path):
		push_error("[FaunaVisualRepresentation ERROR] Model file not found: " + model_path)
		return
		
	var scene_resource := load(model_path) as PackedScene
	if scene_resource == null:
		return
		
	_model_node = scene_resource.instantiate() as Node3D
	_prune_extraneous_nodes(_model_node)
	
	# Apply calibrations
	_model_node.scale = scale_multiplier
	_model_node.position = position_offset
	_model_node.rotation_degrees = rotation_offset
	
	target_parent.add_child(_model_node)
	_register_glb_materials(_model_node)
	
	# Extract and wire skeletal anims
	_anim_player = _model_node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if is_instance_valid(_anim_player) and _anim_player.has_animation(anim_idle_name):
		_anim_player.play(anim_idle_name)


## Concrete Implementation: Drives the built-in blending state-machine in runtime
func animate_movement(velocity_flat: Vector2, is_on_floor: bool, delta: float) -> void:
	if not is_instance_valid(_anim_player) or not is_instance_valid(_host):
		return
		
	# Avoid unused parameter warning in the overridden contract
	var _d := delta
	
	var is_moving := velocity_flat.length_squared() > 0.1
	
	# State blending priority checks
	if is_moving and is_on_floor:
		_play_animation_safe(anim_walk_name, 1.0)
	else:
		_play_animation_safe(anim_idle_name, 1.0)


## Concrete Implementation: Trigger generic jump/hop recoil
func trigger_attack_visuals() -> void:
	pass # Fauna has no weapon slashes, defaults to standard AI panics


func get_collision_box_size() -> Vector3:
	return collision_size


func get_collision_box_position() -> Vector3:
	return collision_position


# ==============================================================================
# INTERNAL UTILITIES & SKELETAL RENDERING COMPILES
# ==============================================================================

## Prevents animation snapping by executing a 0.20s linear crossfade blend
func _play_animation_safe(anim_name: String, speed: float = 1.0) -> void:
	if is_instance_valid(_anim_player) and _anim_player.has_animation(anim_name):
		_anim_player.speed_scale = speed
		if _anim_player.current_animation != anim_name:
			# Execute a 0.20s smooth crossfade blend to prevent mesh snapping!
			_anim_player.play(anim_name, 0.20)


## Recursively duplicates materials and patches tangent warnings
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: Material = node.get_active_material(0) as Material
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0) as Material
			
		if mat is BaseMaterial3D:
			var new_mat := mat.duplicate() as BaseMaterial3D
			
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
