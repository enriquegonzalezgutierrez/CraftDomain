# ==============================================================================
# Project: CraftDomain
# Description: Concrete Skeletal Visual Representation Strategy.
#              Loads, scales, offsets, and animates humanoid Mixamo FBX meshes.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                FBX scene loading, dynamic animation extraction, skeletal 
#                blending, and tangent warning suppression.
# BUG FIX: TANGENT WARNING SHIELD ENHANCEMENT
# - Standardized `_register_glb_materials()` to loop through *every* surface index
#   in the MeshInstance3D using `get_surface_count()`. This ensures that complex
#   humanoid meshes with multiple embedded materials correctly strip their normal maps
#   and tangent requirements, completely eliminating C++ renderer warnings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd
# ==============================================================================
class_name SkeletalVisualRepresentation
extends IEntityVisualRepresentation

@export var base_model_path: String = ""
@export var scale_multiplier: Vector3 = Vector3.ONE
@export var position_offset: Vector3 = Vector3.ZERO
@export var rotation_offset: Vector3 = Vector3.ZERO

@export var anim_idle_path: String = ""
@export var anim_walk_path: String = ""
@export var anim_attack_path: String = ""
@export var anim_panic_path: String = ""
@export var anim_jump_path: String = ""

var _host: CharacterBody3D
var _model_node: Node3D
var _anim_player: AnimationPlayer


func build_representation(host: CharacterBody3D, target_parent: Node3D) -> void:
	_host = host
	
	# 1. HYBRID EDITOR CHECK: Recycle the existing model if it's already in the .tscn
	_anim_player = target_parent.find_child("AnimationPlayer", true, false)
	
	if is_instance_valid(_anim_player):
		_model_node = _anim_player.get_parent() as Node3D
	else:
		# 2. CODE FALLBACK: Instantiate from disk if missing
		if not FileAccess.file_exists(base_model_path):
			push_error("[SkeletalVisualRepresentation] Model file not found: " + base_model_path)
			return
		var scene_resource := load(base_model_path) as PackedScene
		_model_node = scene_resource.instantiate() as Node3D
		target_parent.add_child(_model_node)
		
		# Apply Calibrations ONLY to dynamically code-spawned nodes
		_model_node.scale = scale_multiplier
		_model_node.position = position_offset
		_model_node.rotation_degrees = rotation_offset
		
	_prune_extraneous_nodes(_model_node)
	_register_glb_materials(_model_node)
	
	# Extract and wire skeletal animations dynamically
	_anim_player = _model_node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if is_instance_valid(_anim_player):
		_load_external_fbx_animations()
		_play_animation_safe("idle", 1.0)


func _load_external_fbx_animations() -> void:
	if not is_instance_valid(_anim_player):
		return
		
	# Create a completely fresh, mutable library to store our cloned animations
	var anim_library := AnimationLibrary.new()
	
	var anim_sources := {
		"idle": anim_idle_path,
		"walk": anim_walk_path,
		"attack": anim_attack_path,
		"panic": anim_panic_path,
		"jump": anim_jump_path
	}
	
	for anim_name: String in anim_sources.keys():
		var path: String = anim_sources[anim_name] as String
		if path != "" and FileAccess.file_exists(path):
			var anim_scene := load(path) as PackedScene
			if anim_scene != null:
				var temp_instance := anim_scene.instantiate()
				var temp_player := temp_instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
				
				if is_instance_valid(temp_player) and temp_player.get_animation_list().size() > 0:
					# Filter out "RESET" track, extract the real animation name
					var raw_name := ""
					for a_name in temp_player.get_animation_list():
						if a_name != "RESET":
							raw_name = a_name
							break
							
					if raw_name != "":
						# GODOT 4 FIX: Must .duplicate() to bypass the imported resource Read-Only lock!
						var animation_resource := temp_player.get_animation(raw_name).duplicate() as Animation
						
						if anim_name == "idle" or anim_name == "walk" or anim_name == "panic":
							animation_resource.loop_mode = Animation.LOOP_LINEAR
						elif anim_name == "attack" or anim_name == "jump":
							animation_resource.loop_mode = Animation.LOOP_NONE
							
						anim_library.add_animation(anim_name, animation_resource)
					
				temp_instance.queue_free()
				
	# Register the new custom library safely to the primary AnimationPlayer
	_anim_player.add_animation_library("states", anim_library)


func animate_movement(velocity_flat: Vector2, is_on_floor: bool, _delta: float) -> void:
	if not is_instance_valid(_anim_player) or not is_instance_valid(_host):
		return
		
	var is_talking: bool = _host.get("is_talking") == true if "is_talking" in _host else false
	if is_talking:
		_play_animation_safe("idle", 1.0)
		return
		
	var speed := velocity_flat.length()
	var is_moving := speed > 0.1
	
	var in_panic := false
	var ai_comp := _host.get_node_or_null("NPCAIComponent") as Node
	if is_instance_valid(ai_comp) and "current_task" in ai_comp:
		in_panic = (ai_comp.get("current_task") as int == 5) # TaskState.PANIC = 5
		
	if not is_on_floor:
		_play_animation_safe("jump", 1.0)
	elif is_moving:
		if in_panic:
			if _anim_player.has_animation("states/panic"):
				_play_animation_safe("panic", 1.2)
			else:
				_play_animation_safe("walk", 1.8)
		else:
			var walk_speed := clampf(speed * 0.8, 0.8, 1.5)
			_play_animation_safe("walk", walk_speed)
	else:
		_play_animation_safe("idle", 1.0)


func trigger_attack_visuals() -> void:
	_play_animation_safe("attack", 1.2)


func get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.5, 0.575) 


func get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.75, 0.0) 


func _play_animation_safe(anim_name: String, speed: float = 1.0) -> void:
	# Pre-append the "states" library path
	var full_name := "states/" + anim_name
	if is_instance_valid(_anim_player) and _anim_player.has_animation(full_name):
		_anim_player.speed_scale = speed
		if _anim_player.current_animation != full_name:
			_anim_player.play(full_name, 0.20)


## Recursively duplicates materials over ALL mesh surfaces to suppress tangent errors
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		# Iterate dynamically over every single surface index mapped on the mesh!
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
				
				# Explicitly override the matching surface index!
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
