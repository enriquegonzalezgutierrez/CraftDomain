class_name PigEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1)
	name = "Entity_PIG"

func _build_visual_representation() -> void:
	_create_box(_visual_root, Vector3(0.7, 0.45, 0.9), Vector3(0, 0.35, 0), Color(1.0, 0.62, 0.72))
	_head_node = Node3D.new()
	_head_node.name = "PigHead"
	_head_node.position = Vector3(0, 0.6, -0.45)
	_visual_root.add_child(_head_node)
	_create_box(_head_node, Vector3(0.4, 0.4, 0.4), Vector3(0, 0, 0), Color(1.0, 0.58, 0.68))
	_create_box(_head_node, Vector3(0.22, 0.12, 0.12), Vector3(0, -0.1, -0.22), Color(0.92, 0.38, 0.48))
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.16, 0.05, -0.21), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15))
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.16, 0.05, -0.21), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15))
	_create_box(_visual_root, Vector3(0.18, 0.3, 0.18), Vector3(-0.22, 0.15, -0.28), Color(1.0, 0.62, 0.72))
	_create_box(_visual_root, Vector3(0.18, 0.3, 0.18), Vector3(0.22, 0.15, -0.28), Color(1.0, 0.62, 0.72))
	_create_box(_visual_root, Vector3(0.18, 0.3, 0.18), Vector3(-0.22, 0.15, 0.28), Color(1.0, 0.62, 0.72))
	_create_box(_visual_root, Vector3(0.18, 0.3, 0.18), Vector3(0.22, 0.15, 0.28), Color(1.0, 0.62, 0.72))

func _get_collision_box_size() -> Vector3:
	return Vector3(0.69, 0.69, 0.92)

func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)
