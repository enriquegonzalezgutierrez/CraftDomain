# ==============================================================================
# Pathfile: res://src/Infrastructure/Player/PlayerController.gd
# Description: First-person player physics controller. Manages movement vectors,
#              camera rotations, and input actions.
#              Delegates visual effects, audio, and inputs to sub-components (SRP).
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

# Decoupled Sub-Components (SRP Compliant)
var _input_component: PlayerInputComponent
var _camera_effects: CameraEffectsComponent
var _footstep_player: FootstepAudioPlayer


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
	
	hud = PLAYER_HUD_SCENE.instantiate() as PlayerHUD
	hud.player = self
	hud.world_controller = world_controller
	add_child(hud)
	
	_setup_decoupled_components()


func _setup_decoupled_components() -> void:
	_input_component = PlayerInputComponent.new()
	add_child(_input_component)
	_input_component.initialize(self)
	
	_camera_effects = CameraEffectsComponent.new()
	add_child(_camera_effects)
	_camera_effects.initialize(self, camera)
	
	_footstep_player = FootstepAudioPlayer.new()
	add_child(_footstep_player)
	_footstep_player.initialize(self, world_controller)


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

	_process_hotbar_keys()
	if is_instance_valid(interaction_component) and interaction_component.has_method("process_interaction"):
		interaction_component.call("process_interaction")

	if not is_on_floor():
		velocity.y -= gravity * delta
		if velocity.y < TERMINAL_VELOCITY:
			velocity.y = TERMINAL_VELOCITY
			
	if is_instance_valid(_input_component) and _input_component.is_jump_just_pressed() and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := _input_component.get_movement_vector() if is_instance_valid(_input_component) else Vector2.ZERO
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_flat_velocity := Vector2(velocity.x, velocity.z)
	var target_flat_velocity := Vector2(direction.x, direction.z) * SPEED
	var acceleration := 12.0 if is_on_floor() else 6.0
	current_flat_velocity = current_flat_velocity.lerp(target_flat_velocity, acceleration * delta)
	
	velocity.x = current_flat_velocity.x
	velocity.z = current_flat_velocity.y

	move_and_slide()
	
	if is_instance_valid(_camera_effects):
		_camera_effects.process_camera_effects(delta)
	if is_instance_valid(_footstep_player):
		_footstep_player.process_footsteps(delta, current_flat_velocity)
	if is_instance_valid(visual_component):
		visual_component.animate_movement(current_flat_velocity, is_on_floor(), delta)


func _scroll_hotbar(direction: int) -> void:
	var new_slot := active_slot_index + direction
	if new_slot > 7: new_slot = 0
	elif new_slot < 0: new_slot = 7
	_apply_hotbar_selection(new_slot)


func _process_hotbar_keys() -> void:
	if not is_instance_valid(_input_component):
		return
	var selection := _input_component.get_active_hotkey_selection()
	if selection != -1:
		_apply_hotbar_selection(selection)


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
	if is_instance_valid(_camera_effects):
		_camera_effects.apply_trauma_shake(0.32)


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
