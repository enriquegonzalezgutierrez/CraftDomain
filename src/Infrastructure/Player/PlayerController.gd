# ==============================================================================
# Pathfile: res://src/Infrastructure/Player/PlayerController.gd
# Description: First-person player physics controller. Manages movement vectors,
#              camera rotations, view bobs, and input actions.
#              Refactored to instantiate PlayerHUD via its scene tree.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PlayerController
extends CharacterBody3D

signal sword_swung

const PLAYER_HUD_SCENE := preload("res://src/Infrastructure/UI/player_hud.tscn")

const SPEED: float = 6.0
const JUMP_VELOCITY: float = 6.5
const MOUSE_SENSITIVITY: float = 0.003
const TERMINAL_VELOCITY: float = -20.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_active: bool = false
var domain_entity: VoxelEntity
var inventory: IInventory

var camera: Camera3D
var world_controller: Node3D 
var hud: PlayerHUD
var viewmodel: PlayerViewModel
var interaction_component: Node3D 
var visual_component: PlayerVisualComponent

var active_slot_index: int = 0
var active_build_type: BlockType.Type = BlockType.Type.STONE
var is_item_selected: bool = true 

var _bob_timer: float = 0.0
var _target_camera_pos: Vector3 = Vector3(0.0, 1.6, 0.0)
var _target_camera_tilt: float = 0.0
var _shake_intensity: float = 0.0
var _footstep_accumulator: float = 0.0


func _init() -> void:
	_setup_inputs_mouse_actions()
	domain_entity = VoxelEntity.new(3)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)


func _ready() -> void:
	floor_block_on_wall = false         
	floor_constant_speed = true         
	floor_max_angle = deg_to_rad(45.0)   
	floor_snap_length = 0.25           
	wall_min_slide_angle = 0.0         
	safe_margin = 0.015                
	
	_setup_inputs()
	_setup_player_geometry()
	_setup_sub_components()
	
	var inv_comp := inventory as InventoryComponent
	if is_instance_valid(inv_comp):
		inv_comp.inventory_changed.connect(_on_inventory_changed)
		
	_apply_hotbar_selection(0)


func swing_sword() -> void:
	sword_swung.emit()


func _setup_player_geometry() -> void:
	var col := CollisionShape3D.new()
	col.name = "PlayerCollider"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	col.shape = capsule
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.position = Vector3(0, 1.6, 0) 
	camera.current = true
	add_child(camera)
	
	visual_component = PlayerVisualComponent.new()
	visual_component.name = "PlayerVisualComponent"
	visual_component.is_local_player = true 
	add_child(visual_component)


func _setup_sub_components() -> void:
	inventory = InventoryComponent.new()
	
	viewmodel = PlayerViewModel.new()
	viewmodel.player = self  
	camera.add_child(viewmodel)
	
	var interaction_script := load("res://src/Infrastructure/Player/VoxelInteractionComponent.gd") as GDScript
	if interaction_script != null:
		interaction_component = interaction_script.new() as Node3D
		interaction_component.set("player", self)
		interaction_component.set("world_controller", world_controller)
		camera.add_child(interaction_component)
	
	# Scene-Based instantiation to build child nodes correctly
	hud = PLAYER_HUD_SCENE.instantiate() as PlayerHUD
	hud.player = self
	hud.world_controller = world_controller
	add_child(hud)


func _setup_inputs() -> void:
	var primary_inputs := {
		"move_forward": KEY_W, "move_backward": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"jump": KEY_SPACE, "ui_cancel": KEY_ESCAPE, "select_stone": KEY_1, "select_dirt": KEY_2,
		"select_grass": KEY_3, "select_wood": KEY_4, "select_leaves": KEY_5, "select_lava": KEY_6,
		"select_chicken": KEY_7, "select_sword": KEY_8, "craft_item": KEY_C, "toggle_backpack": KEY_I,
		"free_cursor": KEY_ALT, "toggle_world_map": KEY_M 
	}
	for action_name: String in primary_inputs.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)
		var event := InputEventKey.new()
		event.keycode = primary_inputs[action_name] as Key
		InputMap.action_add_event(action_name, event)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if is_instance_valid(hud):
				hud.toggle_pause_menu(true)
			if is_instance_valid(world_controller) and world_controller.has_method("save_all"):
				world_controller.call("save_all")
		else:
			if is_instance_valid(hud) and hud.is_any_menu_open():
				return
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			if is_instance_valid(hud):
				hud.toggle_pause_menu(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_hotbar(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_hotbar(1)


func _physics_process(delta: float) -> void:
	_process_cursor_grab_state()
	if global_position.y < 2.0:
		_rescue_player_from_void()
	if not is_active:
		return

	if is_instance_valid(world_controller):
		var chunk_manager_ref: Object = world_controller.get("chunk_manager")
		if is_instance_valid(chunk_manager_ref) and "world_state" in world_controller:
			var ws: WorldState = world_controller.world_state
			if is_instance_valid(ws):
				var p_chunk_pos := ws.global_to_chunk_pos(Vector3i(floori(position.x), 0, floori(position.z)))
				if not chunk_manager_ref.call("is_chunk_rendered", p_chunk_pos):
					velocity = Vector3.ZERO
					return

	_process_hotbar_keys()
	if is_instance_valid(interaction_component) and interaction_component.has_method("process_interaction"):
		interaction_component.call("process_interaction")

	if not is_on_floor():
		velocity.y -= gravity * delta
		if velocity.y < TERMINAL_VELOCITY:
			velocity.y = TERMINAL_VELOCITY
			
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_flat_velocity := Vector2(velocity.x, velocity.z)
	var target_flat_velocity := Vector2(direction.x, direction.z) * SPEED
	var acceleration := 12.0 if is_on_floor() else 6.0
	current_flat_velocity = current_flat_velocity.lerp(target_flat_velocity, acceleration * delta)
	
	velocity.x = current_flat_velocity.x
	velocity.z = current_flat_velocity.y

	move_and_slide()
	_process_camera_effects(delta)
	
	if is_on_floor() and current_flat_velocity.length_squared() > 0.25:
		_footstep_accumulator += delta * current_flat_velocity.length()
		if _footstep_accumulator >= 2.2: 
			_footstep_accumulator = 0.0
			_trigger_footstep_sfx(current_flat_velocity)
	else:
		_footstep_accumulator = lerp(_footstep_accumulator, 0.0, delta * 3.0)

	if is_instance_valid(visual_component):
		visual_component.animate_movement(current_flat_velocity, is_on_floor(), delta)


func _trigger_footstep_sfx(_velocity_flat: Vector2) -> void:
	var p_block := Vector3i(floori(global_position.x), floori(global_position.y - 0.1), floori(global_position.z))
	var block_below := BlockType.Type.AIR
	if is_instance_valid(world_controller) and "world_state" in world_controller:
		var ws: WorldState = world_controller.world_state
		if is_instance_valid(ws):
			block_below = ws.get_block(p_block)
		
	var sfx_name := "footstep_stone" 
	match block_below:
		BlockType.Type.GRASS, BlockType.Type.DIRT:
			sfx_name = "footstep_grass"
		BlockType.Type.WOOD, BlockType.Type.LEAVES, BlockType.Type.BIRCH_LOG, BlockType.Type.OAK_PLANKS:
			sfx_name = "footstep_wood"
		BlockType.Type.SNOW, BlockType.Type.ICE:
			sfx_name = "footstep_snow"
		BlockType.Type.AIR, BlockType.Type.WATER:
			return 
			
	AudioService.play_sfx_static(sfx_name, global_position)


func _process_camera_effects(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	var flat_vel := Vector2(velocity.x, velocity.z)
	var horizontal_speed := flat_vel.length()
	
	if is_on_floor() and horizontal_speed > 0.1:
		_bob_timer += delta * horizontal_speed * 2.2
		var bob_y := sin(_bob_timer) * 0.035
		var bob_x := cos(_bob_timer * 0.5) * 0.018
		_target_camera_pos = Vector3(bob_x, 1.6 + bob_y, 0.0)
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		_target_camera_tilt = -input_dir.x * 0.02
	else:
		_bob_timer += delta * 1.5
		var breath_y := sin(_bob_timer) * 0.006
		_target_camera_pos = Vector3(0.0, 1.6 + breath_y, 0.0)
		_target_camera_tilt = 0.0
		
	var current_pos: Vector3 = camera.position.lerp(_target_camera_pos, delta * 10.0)
	var current_tilt: float = lerp(camera.rotation.z, _target_camera_tilt, delta * 8.0)
	
	if _shake_intensity > 0.005:
		var shake_x := randf_range(-_shake_intensity, _shake_intensity) * 0.4
		var shake_y := randf_range(-_shake_intensity, _shake_intensity) * 0.4
		var shake_z := randf_range(-_shake_intensity, _shake_intensity) * 0.4
		current_pos += Vector3(shake_x, shake_y, shake_z)
		current_tilt += randf_range(-_shake_intensity, _shake_intensity) * 0.08
		_shake_intensity = lerp(_shake_intensity, 0.0, delta * 9.0)
	else:
		_shake_intensity = 0.0
		
	camera.position = current_pos
	camera.rotation.z = current_tilt


func _scroll_hotbar(direction: int) -> void:
	var new_slot := active_slot_index + direction
	if new_slot > 7: new_slot = 0
	elif new_slot < 0: new_slot = 7
	_apply_hotbar_selection(new_slot)


func _process_hotbar_keys() -> void:
	if Input.is_action_just_pressed("select_stone"): _apply_hotbar_selection(0)
	elif Input.is_action_just_pressed("select_dirt"): _apply_hotbar_selection(1)
	elif Input.is_action_just_pressed("select_grass"): _apply_hotbar_selection(2)
	elif Input.is_action_just_pressed("select_wood"): _apply_hotbar_selection(3)
	elif Input.is_action_just_pressed("select_leaves"): _apply_hotbar_selection(4)
	elif Input.is_action_just_pressed("select_lava"): _apply_hotbar_selection(5)
	elif Input.is_action_just_pressed("select_chicken"): _apply_hotbar_selection(6)
	elif Input.is_action_just_pressed("select_sword"): _apply_hotbar_selection(7)


func _apply_hotbar_selection(slot: int) -> void:
	active_slot_index = slot
	if is_instance_valid(hud):
		hud.update_active_slot(slot)
	if inventory == null:
		return
		
	var inv_comp := inventory as InventoryComponent
	var slot_data := inv_comp.get_slot_data(slot)
	
	if slot_data == null or slot_data.item_id == -1 or slot_data.quantity == 0:
		is_item_selected = false
		active_build_type = BlockType.Type.AIR
		_set_viewmodel_tool(PlayerViewModel.ToolType.NONE)
		if is_instance_valid(visual_component):
			visual_component.update_held_tool(-1)
		return
		
	var item_id := slot_data.item_id
	if is_instance_valid(visual_component):
		visual_component.update_held_tool(item_id)
		
	var tool_type: PlayerViewModel.ToolType = PlayerViewModel.get_tool_type_for_item(item_id)
	_set_viewmodel_tool(tool_type)
	
	var block_def := BlockLibrary.get_definition(item_id)
	if block_def != null and block_def.type != 0: 
		is_item_selected = true
		active_build_type = item_id as BlockType.Type
	else:
		is_item_selected = false
		active_build_type = BlockType.Type.AIR


func _set_viewmodel_tool(tool_id: PlayerViewModel.ToolType) -> void:
	if is_instance_valid(viewmodel):
		viewmodel.switch_to_tool(tool_id)


func take_damage(amount: int, knockback_force: Vector3) -> void:
	if not is_active or domain_entity.is_dead: return
	velocity += knockback_force
	domain_entity.take_damage(amount)


func _on_domain_entity_took_damage(_amount: int) -> void:
	_shake_intensity = 0.32


func _on_domain_entity_died() -> void:
	domain_entity.health = 3
	domain_entity.is_dead = false
	is_active = false
	if is_instance_valid(hud):
		hud.show_loading_screen()
	position = Vector3(8.5, 14.0, 8.5)
	velocity = Vector3.ZERO
	if is_instance_valid(world_controller):
		world_controller.set("is_teleport_spawn", true)
		var ws: WorldState = world_controller.world_state
		if is_instance_valid(ws):
			var chunk_pos: Vector3i = ws.global_to_chunk_pos(Vector3i(8, 0, 8))
			world_controller.set("_target_spawn_chunk_pos", chunk_pos)


func _on_inventory_changed() -> void:
	_apply_hotbar_selection(active_slot_index)


func _rescue_player_from_void() -> void:
	velocity = Vector3.ZERO
	var block_x := floori(position.x)
	var block_z := floori(position.z)
	var found_safe_y: float = 14.0 
	if is_instance_valid(world_controller) and "world_state" in world_controller:
		var ws: WorldState = world_controller.world_state
		if is_instance_valid(ws):
			found_safe_y = ws.get_highest_solid_y(block_x, block_z)
	global_position.y = found_safe_y


func _process_cursor_grab_state() -> void:
	if not is_instance_valid(hud):
		return
	if Input.is_action_pressed("free_cursor"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if not hud.is_any_menu_open():
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not Input.is_action_pressed("ui_cancel"):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _setup_inputs_mouse_actions() -> void:
	if not InputMap.has_action("click_left"): InputMap.add_action("click_left")
	InputMap.action_erase_events("click_left")
	var left_btn := InputEventMouseButton.new(); left_btn.button_index = MOUSE_BUTTON_LEFT 
	InputMap.action_add_event("click_left", left_btn)
	var left_key := InputEventKey.new(); left_key.keycode = KEY_E
	InputMap.action_add_event("click_left", left_key)
	
	if not InputMap.has_action("click_right"): InputMap.add_action("click_right")
	InputMap.action_erase_events("click_right")
	var right_btn := InputEventMouseButton.new(); right_btn.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("click_right", right_btn)
	var right_key := InputEventKey.new(); right_key.keycode = KEY_Q
	InputMap.action_add_event("click_right", right_key)
