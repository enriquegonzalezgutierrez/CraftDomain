class_name SheepEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1)
	name = "Entity_SHEEP"

func _build_visual_representation() -> void:
	_create_box(_visual_root, Vector3(0.72, 0.55, 0.92), Vector3(0, 0.38, 0), Color(0.95, 0.95, 0.98))
	_head_node = Node3D.new()
	_head_node.name = "SheepHead"
	_head_node.position = Vector3(0, 0.65, -0.48)
	_visual_root.add_child(_head_node)
	_create_box(_head_node, Vector3(0.35, 0.35, 0.35), Vector3(0, 0, 0), Color(0.95, 0.75, 0.65))
	_create_box(_head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.14, 0), Color(0.95, 0.95, 0.98))
	_left_eye = _create_box(_head_node, Vector3(0.07, 0.07, 0.02), Vector3(-0.14, 0.03, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.03, 0.03, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.25))
	_right_eye = _create_box(_head_node, Vector3(0.07, 0.07, 0.02), Vector3(0.14, 0.03, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.03, 0.03, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.25))
	_create_box(_visual_root, Vector3(0.16, 0.28, 0.16), Vector3(-0.22, 0.14, -0.28), Color(0.2, 0.2, 0.22))
	_create_box(_visual_root, Vector3(0.16, 0.28, 0.16), Vector3(0.22, 0.14, -0.28), Color(0.2, 0.2, 0.22))
	_create_box(_visual_root, Vector3(0.16, 0.28, 0.16), Vector3(-0.22, 0.14, 0.28), Color(0.2, 0.2, 0.22))
	_create_box(_visual_root, Vector3(0.16, 0.28, 0.16), Vector3(0.22, 0.14, 0.28), Color(0.2, 0.2, 0.22))

func _get_collision_box_size() -> Vector3:
	return Vector3(0.69, 0.69, 0.92)

func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)
