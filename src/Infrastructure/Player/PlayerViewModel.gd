# ==============================================================================
# Pathfile: res://src/Infrastructure/Player/PlayerViewModel.gd
# Description: First-person arms and tools viewmodel manager. Handles active 
#              hand-held tool meshes, progressive bobbing, click swing animations,
#              and dynamic voxel glider wings.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates first-person 
#   arms drawings, sways, and active hand swing Tweens.
# - Open-Closed Principle (OCP): Implements an extensible tool-mapping registry,
#   allowing glider wings to compile without changing core movement scripts.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PlayerViewModel
extends Node3D

enum ToolType {
	NONE,
	SCROLL,     # Shown when selecting blocks (blueprints)
	PICKAXE,    # Shown when selecting Stone, Dirt, or Grass (mining)
	SWORD,      # Shown when selecting the Sword slot (combat)
	GLIDER      # Shown when the high-altitude glider is deployed (flight)
}

const SWORD_MODEL_PATH := "res://assets/models/weapons/sword.glb"
const PICKAXE_MODEL_PATH := "res://assets/models/weapons/pick.glb"

## Injectable reference to the active Player Controller.
var player: CharacterBody3D

var active_tool: ToolType = ToolType.NONE
var _is_swinging: bool = false

# Internal mesh container nodes
var _tool_root: Node3D

# Viewmodel animation and bobbing trackers
var _bob_time: float = 0.0
var _idle_time: float = 0.0

# Original baseline position offset relative to the Camera (Bottom-Right of screen)
const BASELINE_POSITION := Vector3(0.32, -0.38, -0.52)
const BASELINE_ROTATION := Vector3(deg_to_rad(10), deg_to_rad(20), deg_to_rad(-5))

## Dynamic OCP registry mapping Item IDs to their designated first-person ToolType.
static var _item_tools: Dictionary = {}


static func _static_init() -> void:
	register_item_tool_type(15, ToolType.SCROLL)  # Lava Bucket
	register_item_tool_type(16, ToolType.SCROLL)  # Fried Chicken
	register_item_tool_type(17, ToolType.SWORD)   # Wooden Sword
	register_item_tool_type(18, ToolType.SCROLL)  # Crop Seeds
	register_item_tool_type(210, ToolType.GLIDER) # Voxel Glider


## Public OCP Extension API: Registers a custom item tool type dynamically.
static func register_item_tool_type(item_id: int, tool_type: ToolType) -> void:
	_item_tools[item_id] = tool_type
	print("[PlayerViewModel] Registered dynamic OCP tool type for ID %d -> '%d'" % [item_id, tool_type])


## Static Router: Resolves the appropriate first-person ToolType for any item ID.
static func get_tool_type_for_item(item_id: int) -> ToolType:
	if item_id == -1:
		return ToolType.NONE
		
	# 1. Check custom OCP non-block item tool registrations
	if _item_tools.has(item_id):
		return _item_tools[item_id] as ToolType
		
	# 2. Symmetrical Fallback: Check if the item is a valid registered block
	var def := BlockLibrary.get_definition(item_id as BlockType.Type) as BlockDefinition
	if def != null and def.type != 0: # 0 represents BlockType.Type.AIR
		return ToolType.PICKAXE
		
	return ToolType.NONE


func _ready() -> void:
	name = "PlayerViewModel"
	position = BASELINE_POSITION
	rotation = BASELINE_ROTATION
	
	_tool_root = Node3D.new()
	_tool_root.name = "ToolRoot"
	add_child(_tool_root)
	
	# Start with Scroll by default
	switch_to_tool(ToolType.SCROLL)


func _process(delta: float) -> void:
	if _is_swinging:
		return 
		
	if is_instance_valid(player):
		var flat_velocity := Vector2(player.velocity.x, player.velocity.z)
		var speed: float = flat_velocity.length()
		var is_moving: bool = speed > 0.5 and player.is_on_floor()
		
		# Box Bobbing Math
		var target_pos := BASELINE_POSITION
		
		if is_moving:
			_bob_time += delta * speed * 1.8
			var bob_offset_x: float = cos(_bob_time) * 0.015
			var bob_offset_y: float = abs(sin(_bob_time)) * 0.02 - 0.01
			target_pos += Vector3(bob_offset_x, bob_offset_y, 0.0)
		else:
			_idle_time += delta * 1.5
			var idle_offset_y: float = sin(_idle_time) * 0.008
			var idle_offset_x: float = cos(_idle_time * 0.5) * 0.004
			target_pos += Vector3(idle_offset_x, idle_offset_y, 0.0)
			_bob_time = lerp(_bob_time, 0.0, delta * 5.0)

		position = position.lerp(target_pos, delta * 12.0)


## Programmatically swaps active handheld visual meshes instantly.
func switch_to_tool(new_tool: ToolType) -> void:
	if active_tool == new_tool and _tool_root.get_child_count() > 0:
		return 
		
	active_tool = new_tool
	_clear_tool_mesh()
	
	match active_tool:
		ToolType.SCROLL:
			_build_scroll()
		ToolType.PICKAXE:
			_build_pickaxe()
		ToolType.SWORD:
			_build_sword()
		ToolType.GLIDER:
			_build_glider()


## Executes a highly satisfying 3D swinging animation using God’s Tween engine.
func play_swing_animation() -> void:
	if _is_swinging:
		return
		
	_is_swinging = true
	
	var swing_tween := create_tween()
	var strike_rotation := BASELINE_ROTATION + Vector3(deg_to_rad(-45), deg_to_rad(-25), deg_to_rad(-10))
	var strike_position := BASELINE_POSITION + Vector3(-0.08, -0.05, -0.05)
	
	swing_tween.set_parallel(true)
	swing_tween.tween_property(self, "rotation", strike_rotation, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(self, "position", strike_position, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	swing_tween.chain().set_parallel(true)
	swing_tween.tween_property(self, "rotation", BASELINE_ROTATION, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	swing_tween.tween_property(self, "position", BASELINE_POSITION, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	swing_tween.chain().tween_callback(func() -> void:
		_is_swinging = false
	)


func _clear_tool_mesh() -> void:
	for child in _tool_root.get_children():
		child.queue_free()


func _build_scroll() -> void:
	var paper_color := Color(0.95, 0.95, 0.88)
	var wood_color := Color(0.45, 0.3, 0.15)
	_create_box_mesh(_tool_root, Vector3(0.08, 0.32, 0.08), Vector3(0, 0, 0), paper_color) 
	_create_box_mesh(_tool_root, Vector3(0.02, 0.38, 0.02), Vector3(0, 0, 0), wood_color)  


## Loads the high-fidelity GLB pickaxe scene with robust procedural fallback support
func _build_pickaxe() -> void:
	if ResourceLoader.exists(PICKAXE_MODEL_PATH):
		var model_scene := load(PICKAXE_MODEL_PATH) as PackedScene
		var model_node := model_scene.instantiate() as Node3D
		_prune_extraneous_nodes(model_node)
		
		# First-person viewmodel calibration offsets
		model_node.scale = Vector3(5.5, 5.5, 5.5)
		model_node.position = Vector3(0.15, -0.22, -0.32)
		model_node.rotation_degrees = Vector3(15, 110, -45)
		
		_tool_root.add_child(model_node)
		_register_glb_materials(model_node)
	else:
		var handle_color := Color(0.45, 0.3, 0.15)
		var stone_color := Color(0.48, 0.48, 0.48)
		_create_box_mesh(_tool_root, Vector3(0.04, 0.45, 0.04), Vector3(0, 0, 0), handle_color) 
		_create_box_mesh(_tool_root, Vector3(0.32, 0.06, 0.06), Vector3(0, 0.18, 0.01), stone_color) 
		_create_box_mesh(_tool_root, Vector3(0.06, 0.08, 0.08), Vector3(0, 0.18, 0), Color(0.3, 0.3, 0.3)) 


## Loads the high-fidelity GLB sword scene and applies exact viewmodel offsets
func _build_sword() -> void:
	if ResourceLoader.exists(SWORD_MODEL_PATH):
		var model_scene := load(SWORD_MODEL_PATH) as PackedScene
		var model_node := model_scene.instantiate() as Node3D
		_prune_extraneous_nodes(model_node)
		
		# First-person viewmodel calibration offsets
		model_node.scale = Vector3(0.035, 0.035, 0.035)
		model_node.position = Vector3(0.12, -0.32, -0.42)
		model_node.rotation_degrees = Vector3(180, 45, 0)
		
		_tool_root.add_child(model_node)
		_register_glb_materials(model_node)
	else:
		_build_fallback_sword()


func _build_fallback_sword() -> void:
	var blade_color := Color(0.85, 0.85, 0.85)
	var guard_color := Color(0.85, 0.6, 0.15)
	var hilt_color := Color(0.45, 0.3, 0.15)
	_create_box_mesh(_tool_root, Vector3(0.06, 0.52, 0.02), Vector3(0, 0.18, 0), blade_color) 
	_create_box_mesh(_tool_root, Vector3(0.18, 0.04, 0.05), Vector3(0, -0.08, 0), guard_color) 
	_create_box_mesh(_tool_root, Vector3(0.04, 0.14, 0.04), Vector3(0, -0.16, 0), hilt_color)  


## Esculpe proceduralmente las alas extendidas en primera persona
func _build_glider() -> void:
	var handle_color := Color(0.45, 0.3, 0.15)  # Madera
	var fabric_color := Color(0.92, 0.92, 0.95)  # Tela de nube blanca
	
	# Marco transversal principal del ala delta
	_create_box_mesh(_tool_root, Vector3(0.75, 0.03, 0.03), Vector3(0.0, 0.12, -0.15), handle_color)
	
	# Ala Izquierda (Inclinación diagonal simulada)
	_create_box_mesh(_tool_root, Vector3(0.55, 0.02, 0.38), Vector3(-0.38, 0.12, -0.28), fabric_color)
	_create_box_mesh(_tool_root, Vector3(0.55, 0.03, 0.03), Vector3(-0.38, 0.13, -0.14), handle_color)
	
	# Ala Derecha (Inclinación diagonal simulada)
	_create_box_mesh(_tool_root, Vector3(0.55, 0.02, 0.38), Vector3(0.38, 0.12, -0.28), fabric_color)
	_create_box_mesh(_tool_root, Vector3(0.55, 0.03, 0.03), Vector3(0.38, 0.13, -0.14), handle_color)


## Recursively duplicates materials to prevent material-sharing leaks
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: Material = node.get_active_material(0) as Material
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0) as Material
			
		if mat is BaseMaterial3D:
			var new_mat := mat.duplicate() as BaseMaterial3D
			node.material_override = new_mat
			
	for child: Node in node.get_children():
		_register_glb_materials(child)


## Recursively locates and frees extraneous camera and light nodes
func _prune_extraneous_nodes(node: Node) -> void:
	for i in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		if "Camera" in child.name or "Light" in child.name:
			child.free()
		else:
			_prune_extraneous_nodes(child)


func _create_box_mesh(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_pos
	
	var mat := ORMMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
