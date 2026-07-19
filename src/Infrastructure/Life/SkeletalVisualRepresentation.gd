# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd
# Description: Concrete Skeletal Visual Representation Strategy.
#              Calculates exact, root-node relative paths to Skeleton3D nodes,
#              applying high-performance bone track retargeting in RAM.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SkeletalVisualRepresentation
extends IEntityVisualRepresentation

@export var base_model_path: String = ""
# Legacy paths maintained for interface compatibility but safely ignored
@export var anim_idle_path: String = ""
@export var anim_walk_path: String = ""
@export var anim_attack_path: String = ""
@export var anim_panic_path: String = ""
@export var anim_jump_path: String = ""

var _host: CharacterBody3D
var _model_node: Node3D
var _anim_player: AnimationPlayer

# Cached relative path to the verified Skeleton3D node (e.g. "Node/GeneralSkeleton")
var _resolved_skeleton_path: String = ""


## Builds the 3D representation and triggers failsafe animation compilation.
func build_representation(host: CharacterBody3D, target_parent: Node3D) -> void:
	_host = host
	_anim_player = target_parent.find_child("AnimationPlayer", true, false) as AnimationPlayer
	
	if is_instance_valid(_anim_player):
		_model_node = _anim_player.get_parent() as Node3D
	else:
		if not ResourceLoader.exists(base_model_path):
			push_error("[SkeletalVisualRepresentation] Base model path not found: " + base_model_path)
			return
			
		var scene_resource := load(base_model_path) as PackedScene
		_model_node = scene_resource.instantiate() as Node3D
		target_parent.add_child(_model_node)
		
	GLBModelSanitizer.sanitize_model(_model_node)
	
	# Dynamically discover and cache the actual Skeleton3D node path relative to root (OCP / SRP)
	_resolve_base_skeleton_path()
	
	_anim_player = _model_node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if is_instance_valid(_anim_player):
		_load_external_fbx_animations()
		_play_animation_safe("idle", 1.0)


func _resolve_base_skeleton_path() -> void:
	if not is_instance_valid(_model_node):
		return
		
	# Search recursively for the first Skeleton3D class instance in memory
	var skeleton := _find_skeleton_recursive(_model_node)
	if is_instance_valid(skeleton):
		# Get the exact node path from the root model node down to the skeleton (No "../" required)
		_resolved_skeleton_path = str(_model_node.get_path_to(skeleton))
	else:
		# Sane fallback if no skeleton is found
		_resolved_skeleton_path = "Node/Skeleton3D"


func _load_external_fbx_animations() -> void:
	if not is_instance_valid(_anim_player):
		return
		
	var anim_library := AnimationLibrary.new()
	var anim_sources := {
		"idle": anim_idle_path,
		"walk": anim_walk_path,
		"attack": anim_attack_path,
		"panic": anim_panic_path,
		"jump": anim_jump_path
	}
	
	var skeleton := _find_skeleton_recursive(_model_node)
	if is_instance_valid(skeleton):
		for anim_name: String in anim_sources.keys():
			var path: String = anim_sources[anim_name] as String
			if path != "" and ResourceLoader.exists(path):
				_load_single_animation_track(path, anim_name, anim_library, skeleton, _resolved_skeleton_path)
				
	_anim_player.add_animation_library("states", anim_library)


func _find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton_recursive(child)
		if is_instance_valid(found):
			return found
	return null


func _load_single_animation_track(path: String, anim_name: String, anim_library: AnimationLibrary, skeleton: Skeleton3D, skel_path: String) -> void:
	var anim_scene := EntityPreloaderRegistry.get_skeletal_animation(path)
	if anim_scene == null:
		anim_scene = load(path) as PackedScene
		
	if anim_scene != null:
		_extract_and_normalize_animation(anim_scene, anim_name, anim_library, skeleton, skel_path)


func _extract_and_normalize_animation(anim_scene: PackedScene, anim_name: String, anim_library: AnimationLibrary, skeleton: Skeleton3D, skel_path: String) -> void:
	var temp_instance := anim_scene.instantiate()
	var temp_player := temp_instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
	
	if is_instance_valid(temp_player) and temp_player.get_animation_list().size() > 0:
		var raw_name := ""
		for a_name in temp_player.get_animation_list():
			if a_name != "RESET":
				raw_name = a_name
				break
				
		if raw_name != "":
			var anim := temp_player.get_animation(raw_name).duplicate() as Animation
			_compile_bone_tracks_in_ram(anim, skeleton, skel_path)
			
			if anim_name == "idle" or anim_name == "walk" or anim_name == "panic":
				anim.loop_mode = Animation.LOOP_LINEAR
			else:
				anim.loop_mode = Animation.LOOP_NONE
				
			anim_library.add_animation(anim_name, anim)
			
	temp_instance.queue_free()


## Deconstructs flat-node tracks and compiles native Skeleton3D bone tracks in RAM (SRP).
func _compile_bone_tracks_in_ram(anim: Animation, skeleton: Skeleton3D, skel_path: String) -> void:
	var temp_anim := anim.duplicate() as Animation
	anim.clear() # Wipe all incompatible flat-node tracks
	
	for track_idx in range(temp_anim.get_track_count()):
		var original_path := temp_anim.track_get_path(track_idx)
		var path_str := str(original_path)
		
		# Parse and extract the bone name
		var colon_idx := path_str.find(":")
		var path_part := path_str.substr(0, colon_idx) if colon_idx != -1 else path_str
		var last_slash := path_part.rfind("/")
		var bone_name := path_part.substr(last_slash + 1) if last_slash != -1 else path_part
		
		# Skip if the bone is not registered on our base Skeleton3D model
		if skeleton.find_bone(bone_name) == -1:
			continue
			
		_compile_single_track(anim, temp_anim, track_idx, skel_path, bone_name, colon_idx, path_str)


func _compile_single_track(anim: Animation, temp_anim: Animation, track_idx: int, skel_path: String, bone_name: String, colon_idx: int, path_str: String) -> void:
	var property_name := path_str.substr(colon_idx + 1) if colon_idx != -1 else ""
	var target_bone_path := skel_path + ":" + bone_name
	
	var is_rotation := property_name.contains("rotation") or temp_anim.track_get_type(track_idx) == Animation.TYPE_ROTATION_3D
	var is_position := property_name.contains("position") or property_name.contains("location") or temp_anim.track_get_type(track_idx) == Animation.TYPE_POSITION_3D
	
	if is_rotation:
		var new_track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(new_track, NodePath(target_bone_path))
		_copy_rotation_keys(anim, temp_anim, track_idx, new_track)
	elif is_position:
		var new_track := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(new_track, NodePath(target_bone_path))
		_copy_position_keys(anim, temp_anim, track_idx, new_track)


func _copy_rotation_keys(anim: Animation, temp_anim: Animation, old_track: int, new_track: int) -> void:
	for key_idx in range(temp_anim.track_get_key_count(old_track)):
		var time := temp_anim.track_get_key_time(old_track, key_idx)
		var val: Variant = temp_anim.track_get_key_value(old_track, key_idx)
		
		# Ensure proper Quaternion cast to prevent C++ Mixer crashes
		var quat := Quaternion.IDENTITY
		if val is Quaternion: quat = val
		elif val is Vector4: quat = Quaternion(val.x, val.y, val.z, val.w)
		elif val is Basis: quat = val.get_rotation_quaternion()
		
		anim.rotation_track_insert_key(new_track, time, quat)


func _copy_position_keys(anim: Animation, temp_anim: Animation, old_track: int, new_track: int) -> void:
	for key_idx in range(temp_anim.track_get_key_count(old_track)):
		var time := temp_anim.track_get_key_time(old_track, key_idx)
		var val: Variant = temp_anim.track_get_key_value(old_track, key_idx)
		
		if val is Vector3:
			anim.position_track_insert_key(new_track, time, val)


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
		in_panic = (ai_comp.get("current_task") as int == 5) 
		
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
	var full_name := "states/" + anim_name
	if is_instance_valid(_anim_player) and _anim_player.has_animation(full_name):
		_anim_player.speed_scale = speed
		if _anim_player.current_animation != full_name:
			_anim_player.play(full_name, 0.20)
