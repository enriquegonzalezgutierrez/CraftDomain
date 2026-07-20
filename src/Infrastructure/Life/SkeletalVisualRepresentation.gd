# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd
# Description: Concrete Visual Representation Strategy.
#              REFACTORED: Purged all skeletal animations. Now strictly loads
#              the static .glb mesh and delegates movement to procedural swaying.
# Author: Enrique Gonzalez Gutierrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SkeletalVisualRepresentation
extends IEntityVisualRepresentation

@export var base_model_path: String = ""

# Legacy paths maintained safely as empty strings to fulfill the OCP contract 
# injected from old entity scripts without crashing.
@export var anim_idle_path: String = ""
@export var anim_walk_path: String = ""
@export var anim_attack_path: String = ""
@export var anim_panic_path: String = ""
@export var anim_jump_path: String = ""

var _host: CharacterBody3D
var _model_node: Node3D


## Builds the 3D static representation and sanitizes it for rendering.
func build_representation(host: CharacterBody3D, target_parent: Node3D) -> void:
	_host = host
	
	if not ResourceLoader.exists(base_model_path):
		push_error("[StaticVisual] Base model path not found: " + base_model_path)
		return
		
	var scene_resource := load(base_model_path) as PackedScene
	_model_node = scene_resource.instantiate() as Node3D
	target_parent.add_child(_model_node)
	
	GLBModelSanitizer.sanitize_model(_model_node)


func animate_movement(_velocity_flat: Vector2, _is_on_floor: bool, _delta: float) -> void:
	# Procedural movement and bobbing are already handled automatically 
	# from the _process_procedural_animations function in NPCVisualComponent.gd
	pass


func trigger_attack_visuals() -> void:
	# Apply a simple procedural attack Tween that temporarily rotates the model
	if not is_instance_valid(_model_node) or not is_instance_valid(_host): 
		return
		
	var swing_tween := _host.create_tween()
	var original_rot := _model_node.rotation.x
	
	swing_tween.tween_property(_model_node, "rotation:x", original_rot - 0.5, 0.08).set_trans(Tween.TRANS_SINE)
	swing_tween.tween_property(_model_node, "rotation:x", original_rot + 0.3, 0.12).set_trans(Tween.TRANS_SINE)
	swing_tween.tween_property(_model_node, "rotation:x", original_rot, 0.1).set_trans(Tween.TRANS_SINE)


func get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.5, 0.575) 


func get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.75, 0.0)