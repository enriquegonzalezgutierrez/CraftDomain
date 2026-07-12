# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd
# Description: Concrete Skeletal Visual Representation Strategy.
#              Delegates mesh and material sanitization to GLBModelSanitizer (DRY).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SkeletalVisualRepresentation
extends IEntityVisualRepresentation

@export var base_model_path: String = ""
@export var anim_idle_path: String = ""
@export var anim_walk_path: String = ""
@export var anim_attack_path: String = ""
@export var anim_panic_path: String = ""
@export var anim_jump_path: String = ""

var _host: CharacterBody3D
var _model_node: Node3D
var _anim_player: AnimationPlayer


## Locates the scene's existing model or instantiates a fallback
func build_representation(host: CharacterBody3D, target_parent: Node3D) -> void:
	_host = host
	_anim_player = target_parent.find_child("AnimationPlayer", true, false) as AnimationPlayer
	
	if is_instance_valid(_anim_player):
		_model_node = _anim_player.get_parent() as Node3D
	else:
		if not FileAccess.file_exists(base_model_path):
			push_error("[SkeletalVisualRepresentation] Model file not found: " + base_model_path)
			return
			
		var scene_resource := load(base_model_path) as PackedScene
		_model_node = scene_resource.instantiate() as Node3D
		target_parent.add_child(_model_node)
		
	# Centralized OCP/DRY Cleanup
	GLBModelSanitizer.sanitize_model(_model_node)
	
	_anim_player = _model_node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if is_instance_valid(_anim_player):
		_load_external_fbx_animations()
		_play_animation_safe("idle", 1.0)


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
	
	for anim_name: String in anim_sources.keys():
		var path: String = anim_sources[anim_name] as String
		if path != "" and FileAccess.file_exists(path):
			var anim_scene := load(path) as PackedScene
			if anim_scene != null:
				var temp_instance := anim_scene.instantiate()
				var temp_player := temp_instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
				
				if is_instance_valid(temp_player) and temp_player.get_animation_list().size() > 0:
					var raw_name := ""
					for a_name in temp_player.get_animation_list():
						if a_name != "RESET":
							raw_name = a_name
							break
							
					if raw_name != "":
						var animation_resource := temp_player.get_animation(raw_name).duplicate() as Animation
						if anim_name == "idle" or anim_name == "walk" or anim_name == "panic":
							animation_resource.loop_mode = Animation.LOOP_LINEAR
						elif anim_name == "attack" or anim_name == "jump":
							animation_resource.loop_mode = Animation.LOOP_NONE
							
						anim_library.add_animation(anim_name, animation_resource)
				temp_instance.queue_free()
				
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
