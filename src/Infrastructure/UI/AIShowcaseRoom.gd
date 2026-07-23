# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/AIShowcaseRoom.gd
# Description: Self-contained AI and Entity 3D Sandbox Laboratory. Generates mock 
#              surroundings, A* navigation nodes, and spawner interfaces.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AIShowcaseRoom
extends Node3D

signal subject_spawned(node: CharacterBody3D)
signal subject_despawned

const PLATFORM_SIZE: int = 16
const PLATFORM_Y: int = 11
const CAMPFIRE_PROP_ID: int = 203
const HALF_BLOCK_OFFSET: float = 0.5

const CAMERA_POS := Vector3(0.0, 22.0, 14.5)
const CAMERA_ROT := Vector3(-55.0, 0.0, 0.0)
const LIGHT_ENERGY_VAL: float = 1.6
const LIGHT_ROT := Vector3(-45.0, 35.0, 0.0)

const MOCK_CAMPFIRE_POS := Vector3(4.5, 12.0, 4.5)
const MOCK_PLAYER_POS := Vector3(-4.5, 12.0, -4.5)

const COLOR_EVEN_TILE := Color(0.18, 0.18, 0.22)
const COLOR_ODD_TILE := Color(0.12, 0.12, 0.15)
const COLOR_DUMMY_PLAYER := Color(1.0, 0.15, 0.15)

const DASHBOARD_SCENE_PATH: String = "res://src/Infrastructure/UI/ai_showcase_dashboard.tscn"

var world_state: WorldState
var navigation_service: VoxelNavigationService
var generator: WorldGenerator
var player: CharacterBody3D

var _active_test_subject: CharacterBody3D = null
var _simulated_campfire: StaticBody3D = null
var _mock_weather_service: Node = null


func _ready() -> void:
	name = "AIShowcaseRoom"
	_setup_mock_world_state()
	_build_3d_testing_pad()
	_setup_mock_player_dummy()
	_setup_mock_weather_loop()
	_instantiate_decoupled_dashboard()


func spawn_test_subject(spawn_id: int) -> void:
	_flush_active_test_subject()
	
	var spawn_pos := Vector3(0.0, float(PLATFORM_Y) + 1.5, 0.0) 
	_active_test_subject = MobRegistry.create_mob(spawn_id, spawn_pos) as CharacterBody3D
	
	if is_instance_valid(_active_test_subject):
		_active_test_subject.set_meta("spawn_id", spawn_id)
		add_child(_active_test_subject)
		subject_spawned.emit(_active_test_subject)


func _flush_active_test_subject() -> void:
	if is_instance_valid(_active_test_subject):
		_active_test_subject.queue_free()
		_active_test_subject = null
		subject_despawned.emit()
		
	for child in get_children():
		if child is CharacterBody3D and child != player and child != _active_test_subject:
			child.queue_free()


func _setup_mock_world_state() -> void:
	world_state = WorldState.new()
	navigation_service = VoxelNavigationService.new()
	generator = WorldGenerator.new(42) 
	
	for x: int in range(PLATFORM_SIZE):
		for z: int in range(PLATFORM_SIZE):
			for y in range(8, PLATFORM_Y + 1):
				var global_pos := Vector3i(x - 8, y, z - 8)
				world_state.set_block(global_pos, BlockType.Type.STONE)
				
			var top_pos := Vector3i(x - 8, PLATFORM_Y, z - 8)
			navigation_service.add_navigation_node(top_pos, false)
			
	_connect_mock_navigation_grid()


func _connect_mock_navigation_grid() -> void:
	for x: int in range(-8, 8):
		for z: int in range(-8, 8):
			var node_pos := Vector3i(x, PLATFORM_Y, z)
			var directions: Array[Vector3i] = [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
			for offset: Vector3i in directions:
				var neighbor: Vector3i = node_pos + offset
				if navigation_service._coord_to_id.has(neighbor):
					navigation_service.connect_nodes(node_pos, neighbor)


func _setup_mock_player_dummy() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_meta("is_active", true)
	player.set("inventory", InventoryComponent.new())
	player.set("active_slot_index", 6)
	player.set("is_active", true)
	
	var col := CollisionShape3D.new()
	var _cap := CapsuleShape3D.new()
	_cap.radius = 0.4
	_cap.height = 1.8
	col.shape = _cap
	col.position = Vector3(0.0, 0.9, 0.0)
	player.add_child(col)
	
	_attach_visual_player_geometry_mesh()
	add_child(player)
	player.position = MOCK_PLAYER_POS


func _attach_visual_player_geometry_mesh() -> void:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.4
	cyl.height = 1.8
	mesh.mesh = cyl
	mesh.position = Vector3(0.0, 0.9, 0.0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_DUMMY_PLAYER
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	player.add_child(mesh)


func _setup_mock_weather_loop() -> void:
	_mock_weather_service = Node.new()
	_mock_weather_service.name = "WeatherService"
	
	var mock_script := GDScript.new()
	mock_script.source_code = "extends Node\nvar current_weather: int = 0\n"
	mock_script.reload()
	_mock_weather_service.set_script(mock_script)
	
	add_child(_mock_weather_service)


func _build_3d_testing_pad() -> void:
	var camera := Camera3D.new()
	camera.name = "ShowcaseCamera"
	camera.position = CAMERA_POS
	camera.rotation_degrees = CAMERA_ROT
	add_child(camera)
	
	var light := DirectionalLight3D.new()
	light.light_energy = LIGHT_ENERGY_VAL
	light.light_color = Color(0.99, 0.96, 0.92)
	light.rotation_degrees = LIGHT_ROT
	add_child(light)
	
	_build_physical_testing_platform()


func _build_physical_testing_platform() -> void:
	var checker_root := Node3D.new()
	checker_root.name = "CheckerFloor"
	add_child(checker_root)
	
	for x: int in range(-8, 8):
		for z: int in range(-8, 8):
			var box := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.0, 0.1, 1.0)
			box.mesh = bm
			box.position = Vector3(float(x) + HALF_BLOCK_OFFSET, float(PLATFORM_Y) + 0.95, float(z) + HALF_BLOCK_OFFSET)
			
			var mat := StandardMaterial3D.new()
			var is_even := ((x + z) % 2 == 0)
			mat.albedo_color = COLOR_EVEN_TILE if is_even else COLOR_ODD_TILE
			mat.roughness = 0.9
			box.material_override = mat
			checker_root.add_child(box)
			
	_setup_platform_colliders(checker_root)


func _setup_platform_colliders(checker_root: Node) -> void:
	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(16.0, 1.0, 16.0)
	floor_col.shape = floor_shape
	floor_body.position = Vector3(0.0, float(PLATFORM_Y) + HALF_BLOCK_OFFSET, 0.0)
	floor_body.add_child(floor_col) 
	checker_root.add_child(floor_body)
	
	_setup_containment_walls(checker_root)
	
	if PropRegistry.has_prop(CAMPFIRE_PROP_ID):
		_simulated_campfire = PropRegistry.create_prop(CAMPFIRE_PROP_ID, MOCK_CAMPFIRE_POS) as StaticBody3D
		if is_instance_valid(_simulated_campfire):
			add_child(_simulated_campfire)


func _setup_containment_walls(checker_root: Node) -> void:
	var walls_config: Array[Array] = [
		[Vector3(0, PLATFORM_Y + 6.0, -9.0), Vector3(18, 10, 2)], 
		[Vector3(0, PLATFORM_Y + 6.0, 9.0), Vector3(18, 10, 2)],  
		[Vector3(9.0, PLATFORM_Y + 6.0, 0), Vector3(2, 10, 18)],  
		[Vector3(-9.0, PLATFORM_Y + 6.0, 0), Vector3(2, 10, 18)]  
	]
	for w_data: Array in walls_config:
		var wb := StaticBody3D.new()
		var wc := CollisionShape3D.new()
		var ws := BoxShape3D.new()
		ws.size = w_data[1] as Vector3
		wc.shape = ws
		wb.position = w_data[0] as Vector3
		wb.add_child(wc)
		checker_root.add_child(wb)
		
	_register_containment_walls_in_world_state()


func _register_containment_walls_in_world_state() -> void:
	if world_state == null: return
	for y in range(PLATFORM_Y + 1, PLATFORM_Y + 10):
		for x in range(-9, 10):
			world_state.set_block(Vector3i(x, y, -9), BlockType.Type.STONE)
			world_state.set_block(Vector3i(x, y, 9), BlockType.Type.STONE)
		for z in range(-9, 10):
			world_state.set_block(Vector3i(-9, y, z), BlockType.Type.STONE)
			world_state.set_block(Vector3i(9, y, z), BlockType.Type.STONE)


func _instantiate_decoupled_dashboard() -> void:
	if ResourceLoader.exists(DASHBOARD_SCENE_PATH):
		var scene := load(DASHBOARD_SCENE_PATH) as PackedScene
		if is_instance_valid(scene):
			var dashboard := scene.instantiate() as CanvasLayer
			add_child(dashboard)
