# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/FaunaVisualRepresentation.gd
# Description: Concrete Fauna Visual Representation Strategy.
#              Delegates mesh and material sanitization to GLBModelSanitizer (DRY).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FaunaVisualRepresentation
extends IEntityVisualRepresentation

@export var model_path: String = ""
@export var anim_idle_name: String = "idle"
@export var anim_walk_path: String = "walk" 

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
		if not FileAccess.file_exists(model_path):
			push_error("[FaunaVisualRepresentation] Model file not found: " + model_path)
			return
			
		var scene_resource := load(model_path) as PackedScene
		_model_node = scene_resource.instantiate() as Node3D
		target_parent.add_child(_model_node)
		
	# Centralized OCP/DRY Cleanup
	GLBModelSanitizer.sanitize_model(_model_node)
	
	_anim_player = _model_node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if is_instance_valid(_anim_player) and _anim_player.has_animation(anim_idle_name):
		_play_animation_safe(anim_idle_name, 1.0)


func animate_movement(velocity_flat: Vector2, is_on_floor: bool, _delta: float) -> void:
	if not is_instance_valid(_anim_player) or not is_instance_valid(_host):
		return
		
	var is_moving := velocity_flat.length_squared() > 0.1
	if is_moving and is_on_floor:
		_play_animation_safe(anim_walk_path, 1.0)
	else:
		_play_animation_safe(anim_idle_name, 1.0)


func trigger_attack_visuals() -> void:
	pass 


func get_collision_box_size() -> Vector3:
	return Vector3(0.6, 0.8, 0.6)


func get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.4, 0.0)


func _play_animation_safe(anim_name: String, speed: float = 1.0) -> void:
	if is_instance_valid(_anim_player) and _anim_player.has_animation(anim_name):
		_anim_player.speed_scale = speed
		if _anim_player.current_animation != anim_name:
			_anim_player.play(anim_name, 0.20)
