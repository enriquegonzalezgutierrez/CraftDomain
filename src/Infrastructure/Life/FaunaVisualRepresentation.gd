# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation / Visual Strategies)
# Class: FaunaVisualRepresentation
# Description: Concrete Fauna Visual Representation Strategy.
#              Extracts and triggers built-in animations for quadruped and wildlife 
#              GLB meshes while suppressing material tangent warnings.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively animation states 
#   and material corrections. It explicitly relies on the Godot Editor (.tscn) 
#   for all physical dimensions, removing code-based scaling/rotation interference.
# - Dependency Inversion Principle (DIP): Receives the host and parent nodes 
#   via injection, keeping it decoupled from specific entity physics.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name FaunaVisualRepresentation
extends IEntityVisualRepresentation

# Configurable fallback paths
@export var model_path: String = ""

# Baked internal animation track names (customizable per GLB export)
@export var anim_idle_name: String = "idle"
@export var anim_walk_path: String = "walk" # Matches the generic "walk" animation inside the FBX

# Internal state tracking
var _host: CharacterBody3D
var _model_node: Node3D
var _anim_player: AnimationPlayer


## Concrete Implementation: Locates the scene's existing model or instantiates a fallback,
## leaving all transform matrices (scale/position/rotation) completely untouched.
func build_representation(host: CharacterBody3D, target_parent: Node3D) -> void:
	_host = host
	
	# 1. HYBRID EDITOR CHECK: Trust the SceneTree! 
	# Look for an existing AnimationPlayer in the injected scene parent.
	_anim_player = target_parent.find_child("AnimationPlayer", true, false)
	
	if is_instance_valid(_anim_player):
		_model_node = _anim_player.get_parent() as Node3D
	else:
		# 2. CODE FALLBACK: Instantiate from disk if missing from the .tscn
		if not FileAccess.file_exists(model_path):
			push_error("[FaunaVisualRepresentation] Model file not found: " + model_path)
			return
			
		var scene_resource := load(model_path) as PackedScene
		_model_node = scene_resource.instantiate() as Node3D
		target_parent.add_child(_model_node)
		# Note: We do NOT apply scale or rotation here anymore. We trust the raw asset.
		
	_prune_extraneous_nodes(_model_node)
	_register_glb_materials(_model_node)
	
	# Extract and wire skeletal animations dynamically
	_anim_player = _model_node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if is_instance_valid(_anim_player) and _anim_player.has_animation(anim_idle_name):
		_play_animation_safe(anim_idle_name, 1.0)


## Concrete Implementation: Drives the built-in blending state-machine at runtime
func animate_movement(velocity_flat: Vector2, is_on_floor: bool, delta: float) -> void:
	if not is_instance_valid(_anim_player) or not is_instance_valid(_host):
		return
		
	# Avoid unused parameter warning in the overridden contract
	var _d := delta
	
	var is_moving := velocity_flat.length_squared() > 0.1
	
	# State blending priority checks
	if is_moving and is_on_floor:
		_play_animation_safe(anim_walk_path, 1.0)
	else:
		_play_animation_safe(anim_idle_name, 1.0)


## Concrete Implementation: Trigger generic jump/hop recoil
func trigger_attack_visuals() -> void:
	pass # Fauna has no weapon slashes, defaults to standard AI panics


# Collision dimensions are supplied natively by the Godot Editor .tscn now
func get_collision_box_size() -> Vector3:
	return Vector3(0.6, 0.8, 0.6)


func get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.4, 0.0)


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


## Recursively duplicates materials over ALL mesh surfaces to suppress C++ tangent errors
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		# Iterate dynamically over every single surface index mapped on the mesh
		for i: int in range(node.mesh.get_surface_count()):
			var mat: Material = node.get_active_material(i)
			if mat == null:
				mat = node.mesh.surface_get_material(i)
				
			if mat is BaseMaterial3D:
				var new_mat := mat.duplicate() as BaseMaterial3D
				# TANGENT WARNING SHIELD
				new_mat.normal_enabled = false
				new_mat.anisotropy_enabled = false
				new_mat.clearcoat_enabled = false
				new_mat.heightmap_enabled = false
				
				# Explicitly override the matching surface index
				node.set_surface_override_material(i, new_mat)
				
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
