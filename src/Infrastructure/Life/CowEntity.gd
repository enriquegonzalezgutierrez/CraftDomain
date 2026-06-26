class_name CowEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1)
	name = "Entity_COW"

func _build_visual_representation() -> void:
	_create_box(_visual_root, Vector3(0.75, 0.72, 1.15), Vector3(0, 0.45, 0), Color(0.18, 0.18, 0.18))
	_create_box(_visual_root, Vector3(0.77, 0.42, 0.42), Vector3(0, 0.52, -0.12), Color(0.98, 0.98, 0.98))
	_create_box(_visual_root, Vector3(0.77, 0.32, 0.32), Vector3(0, 0.35, 0.22), Color(0.98, 0.98, 0.98))
	_head_node = Node3D.new()
	_head_node.name = "CowHead"
	_head_node.position = Vector3(0, 0.78, -0.62)
	_visual_root.add_child(_head_node)
	_create_box(_head_node, Vector3(0.42, 0.42, 0.42), Vector3(0, 0, 0), Color(0.18, 0.18, 0.18))
	_create_box(_head_node, Vector3(0.32, 0.18, 0.18), Vector3(0, -0.08, -0.22), Color(0.95, 0.65, 0.65))
	_create_box(_head_node, Vector3(0.06, 0.18, 0.06), Vector3(-0.22, 0.22, 0), Color(0.92, 0.92, 0.88))
	_create_box(_head_node, Vector3(0.06, 0.18, 0.06), Vector3(0.22, 0.22, 0), Color(0.92, 0.92, 0.88))
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.18, 0.03, -0.22), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15))
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.18, 0.03, -0.22), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.12, 0.12, 0.15))
	_create_box(_visual_root, Vector3(0.22, 0.4, 0.22), Vector3(-0.25, 0.2, -0.35), Color(0.18, 0.18, 0.18))
	_create_box(_visual_root, Vector3(0.22, 0.4, 0.22), Vector3(0.25, 0.2, -0.35), Color(0.18, 0.18, 0.18))
	_create_box(_visual_root, Vector3(0.22, 0.4, 0.22), Vector3(-0.25, 0.2, 0.35), Color(0.18, 0.18, 0.18))
	_create_box(_visual_root, Vector3(0.22, 0.4, 0.22), Vector3(0.25, 0.2, 0.35), Color(0.18, 0.18, 0.18))

func _get_collision_box_size() -> Vector3:
	return Vector3(0.69, 0.69, 0.92)

func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)
