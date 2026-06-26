class_name ChickenEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1)
	name = "Entity_CHICKEN"

func _build_visual_representation() -> void:
	_create_box(_visual_root, Vector3(0.35, 0.35, 0.45), Vector3(0, 0.35, 0), Color(0.98, 0.98, 0.98))
	_head_node = Node3D.new()
	_head_node.name = "ChickenHead"
	_head_node.position = Vector3(0, 0.58, -0.22)
	_visual_root.add_child(_head_node)
	_create_box(_head_node, Vector3(0.2, 0.25, 0.2), Vector3(0, 0, 0), Color(0.98, 0.98, 0.98))
	_create_box(_head_node, Vector3(0.18, 0.09, 0.14), Vector3(0, 0, -0.13), Color(1.0, 0.62, 0.0))
	_create_box(_head_node, Vector3(0.08, 0.12, 0.08), Vector3(0, -0.12, -0.05), Color(0.92, 0.1, 0.1))
	_left_eye = _create_box(_head_node, Vector3(0.06, 0.06, 0.02), Vector3(-0.08, 0.05, -0.11), Color.WHITE)
	_create_box(_left_eye, Vector3(0.03, 0.03, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15))
	_right_eye = _create_box(_head_node, Vector3(0.06, 0.06, 0.02), Vector3(0.08, 0.05, -0.11), Color.WHITE)
	_create_box(_right_eye, Vector3(0.03, 0.03, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15))
	_create_box(_visual_root, Vector3(0.06, 0.18, 0.06), Vector3(-0.09, 0.09, 0), Color(1.0, 0.62, 0.0))
	_create_box(_visual_root, Vector3(0.06, 0.18, 0.06), Vector3(0.09, 0.09, 0), Color(1.0, 0.62, 0.0))

func _get_collision_box_size() -> Vector3:
	return Vector3(0.46, 0.69, 0.46)

func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)

func _is_avian() -> bool:
	return true
