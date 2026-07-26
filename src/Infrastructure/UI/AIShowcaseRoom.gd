# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/AIShowcaseRoom.gd
# Description: Self-contained AI 3D Sandbox Laboratory running the exact real-world
#              Grand Castle wall layouts, Voxel Chunk rendering, and ConcavePolygonShape3D
#              physics pipeline to perfect Villager navigation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AIShowcaseRoom
extends Node3D

signal subject_spawned(node: CharacterBody3D)
signal subject_despawned

const CAMERA_POS := Vector3(8.0, 26.0, 24.0)
const CAMERA_ROT := Vector3(-45.0, 0.0, 0.0)
const LIGHT_ENERGY_VAL: float = 1.6
const LIGHT_ROT := Vector3(-45.0, 35.0, 0.0)

const MOCK_PLAYER_POS := Vector3(2.5, 13.0, 2.5)
const COLOR_DUMMY_PLAYER := Color(1.0, 0.15, 0.15)
const DASHBOARD_SCENE_PATH: String = "res://src/Infrastructure/UI/ai_showcase_dashboard.tscn"

var world_state: WorldState
var navigation_service: VoxelNavigationService
var generator: WorldGenerator
var player: CharacterBody3D
var direct_renderer: DirectChunkRenderingService

var _active_test_subject: CharacterBody3D = null
var _mock_weather_service: Node = null
var _testing_chunk: Chunk = null


func _ready() -> void:
	name = "AIShowcaseRoom"
	_setup_rendering_and_world()
	_build_real_castle_voxel_chunk()
	_setup_mock_player_dummy()
	_setup_mock_weather_loop()
	_instantiate_decoupled_dashboard()
	
	# Automatically spawn Villager (ID 100) for testing
	spawn_test_subject(100)


func spawn_test_subject(spawn_id: int) -> void:
	_flush_active_test_subject()
	
	# Spawn test subject in the castle courtyard corridor at Vector3(8.0, 13.0, 8.0)
	var spawn_pos := Vector3(8.0, 13.0, 8.0) 
	_active_test_subject = MobRegistry.create_mob(spawn_id, spawn_pos) as CharacterBody3D
	
	if is_instance_valid(_active_test_subject):
		_active_test_subject.set_meta("spawn_id", spawn_id)
		add_child(_active_test_subject)
		subject_spawned.emit(_active_test_subject)


func _setup_rendering_and_world() -> void:
	world_state = WorldState.new()
	navigation_service = VoxelNavigationService.new()
	generator = WorldGenerator.new(42)
	
	var scenario := get_world_3d().scenario if is_inside_tree() else RID()
	var space := get_world_3d().space if is_inside_tree() else RID()
	direct_renderer = DirectChunkRenderingService.new(self, scenario, space)
	
	_setup_showcase_camera_and_light()


func _setup_showcase_camera_and_light() -> void:
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


## Builds a REAL Voxel Chunk with exact Grand Castle walls, corridors, and doorways
func _build_real_castle_voxel_chunk() -> void:
	_testing_chunk = Chunk.new(Vector3i(0, 0, 0))
	
	# 1. Fill base foundation floor (Y=0 to 12)
	for x in range(Chunk.SIZE):
		for z in range(Chunk.SIZE):
			for y in range(0, 12):
				_testing_chunk.set_block(x, y, z, BlockType.Type.STONE)
			_testing_chunk.set_block(x, 12, z, BlockType.Type.GRASS)
			
	# 2. Build exact castle walls matching GrandCastleMegaStructure style
	_sculpt_castle_walls_and_corridors(_testing_chunk)
	
	# 3. Commit chunk voxels to WorldState & Navigation Graph
	world_state.add_chunk(_testing_chunk)
	_compile_chunk_navigation_nodes(_testing_chunk)
	
	# 4. Extract visual MultiMesh and ConcavePolygonShape3D physics
	_compile_real_chunk_rendering_and_physics(_testing_chunk)


func _sculpt_castle_walls_and_corridors(chunk: Chunk) -> void:
	# Main Outer Castle Wall with doorway arches
	for z in range(2, 14):
		_sculpt_wall_column(chunk, 4, z, 3, BlockType.Type.STONE_BRICKS)
		_sculpt_wall_column(chunk, 12, z, 3, BlockType.Type.STONE_BRICKS)
		
	# Cross Partition Walls with doorways
	for x in range(4, 13):
		_sculpt_wall_column(chunk, x, 2, 3, BlockType.Type.STONE_BRICKS)
		_sculpt_wall_column(chunk, x, 13, 3, BlockType.Type.STONE_BRICKS)
		
	# Doorway Archways (Air gaps)
	_carve_doorway_arch(chunk, 4, 7)
	_carve_doorway_arch(chunk, 12, 7)
	_carve_doorway_arch(chunk, 8, 2)


func _sculpt_wall_column(chunk: Chunk, x: int, z: int, height: int, block_type: BlockType.Type) -> void:
	for h in range(height):
		chunk.set_block(x, 13 + h, z, block_type)


func _carve_doorway_arch(chunk: Chunk, x: int, z: int) -> void:
	chunk.set_block(x, 13, z, BlockType.Type.AIR)
	chunk.set_block(x, 14, z, BlockType.Type.AIR)


func _compile_chunk_navigation_nodes(chunk: Chunk) -> void:
	var nav_nodes := ChunkNavigationBuilder.compile_walkable_nodes_asynchronous(chunk, world_state)
	ChunkNavigationBuilder.register_compiled_nodes_synchronous(nav_nodes, world_state, navigation_service)


func _compile_real_chunk_rendering_and_physics(chunk: Chunk) -> void:
	var visual_data := ChunkVisualBuilder.extract_render_data(chunk, world_state, true)
	var liquid_meshes := ChunkMesher.generate_special_meshes(chunk, world_state)
	
	var col_verts: PackedVector3Array = visual_data.get("collision_vertices", PackedVector3Array()) as PackedVector3Array
	var shape: ConcavePolygonShape3D = null
	if col_verts.size() > 0:
		shape = ConcavePolygonShape3D.new()
		shape.set_faces(col_verts)
		shape.backface_collision = true
		
	var multimesh_data: Dictionary = visual_data.get("multimesh", {}) as Dictionary
	direct_renderer.allocate_chunk_visuals(Vector3i.ZERO, multimesh_data, liquid_meshes, shape, false)


func _flush_active_test_subject() -> void:
	if is_instance_valid(_active_test_subject):
		_active_test_subject.queue_free()
		_active_test_subject = null
		subject_despawned.emit()


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


func _instantiate_decoupled_dashboard() -> void:
	if ResourceLoader.exists(DASHBOARD_SCENE_PATH):
		var scene := load(DASHBOARD_SCENE_PATH) as PackedScene
		if is_instance_valid(scene):
			var dashboard := scene.instantiate() as CanvasLayer
			add_child(dashboard)


func _exit_tree() -> void:
	if is_instance_valid(direct_renderer):
		direct_renderer.clear_all()
