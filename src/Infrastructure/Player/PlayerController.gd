# ==============================================================================
# Pathfile: res://src/Infrastructure/Player/PlayerController.gd
# Description: First-person player physics controller managing movements,
#              LOD views, and stable gravity-free startup phases.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Decoupled hotbar and equipment logic 
#   entirely into PlayerEquipmentComponent.
# - SOLID OCP: Replaced hardcoded block ID lists in _check_in_liquid_state with 
#   the new polymorphic BlockDefinition is_liquid check.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PlayerController
extends CharacterBody3D

signal sword_swung

const PLAYER_HUD_SCENE := preload("res://src/Infrastructure/UI/player_hud.tscn")
const GLIDER_ITEM_ID: int = 210

const SPEED: float = 6.0
const JUMP_VELOCITY: float = 6.5
const MOUSE_SENSITIVITY: float = 0.003
const TERMINAL_VELOCITY: float = -20.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_active: bool = false:
	set(val):
		is_active = val
		if not is_active:
			is_glider_deployed = false
			if is_instance_valid(visual_component):
				visual_component.set_glider_wings_visible(false)

var domain_entity: VoxelEntity
var inventory: IInventory

var camera: Camera3D
var world_controller: Node3D 
var hud: PlayerHUD
var viewmodel: PlayerViewModel
var interaction_component: Node3D 
var visual_component: PlayerVisualComponent

# Proxies connected to PlayerEquipmentComponent (SRP Compliance)
var equipment_component: PlayerEquipmentComponent

var active_slot_index: int:
	get: return equipment_component.active_slot_index if is_instance_valid(equipment_component) else 0
	set(val): if is_instance_valid(equipment_component): equipment_component.apply_hotbar_selection(val)

var active_build_type: BlockType.Type:
	get: return equipment_component.active_build_type if is_instance_valid(equipment_component) else BlockType.Type.STONE

var is_item_selected: bool:
	get: return equipment_component.is_item_selected if is_instance_valid(equipment_component) else false

var is_glider_deployed: bool = false
var _glider_physics: GliderPhysicsStrategy

var _input_component: PlayerInputComponent
var _camera_effects: CameraEffectsComponent
var _footstep_player: FootstepAudioPlayer


func _init() -> void:
	domain_entity = VoxelEntity.new(3)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)
	_glider_physics = GliderPhysicsStrategy.new()


func _ready() -> void:
	floor_block_on_wall = false         
	floor_constant_speed = true         
	floor_max_angle = deg_to_rad(45.0)   
	floor_snap_length = 0.25           
	wall_min_slide_angle = 0.0         
	safe_margin = 0.015                
	
	_setup_player_geometry()
	if is_multiplayer_authority():
		_setup_sub_components()
		var inv_comp := inventory as InventoryComponent
		if is_instance_valid(inv_comp):
			inv_comp.inventory_changed.connect(_on_inventory_changed)
		if is_instance_valid(equipment_component):
			equipment_component.apply_hotbar_selection(0)


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
	
	visual_component = PlayerVisualComponent.new()
	visual_component.name = "PlayerVisualComponent"
	visual_component.is_local_player = is_multiplayer_authority() 
	add_child(visual_component)
	
	if is_multiplayer_authority():
		camera = Camera3D.new()
		camera.name = "PlayerCamera"
		camera.position = Vector3(0, 1.6, 0) 
		camera.current = true
		
		var camera_attrs := CameraAttributesPractical.new()
		camera_attrs.auto_exposure_enabled = true
		camera_attrs.auto_exposure_scale = 0.35 
		camera_attrs.auto_exposure_speed = 1.2  
		camera.attributes = camera_attrs
		
		add_child(camera)


func _setup_sub_components() -> void:
	inventory = InventoryComponent.new()
	viewmodel = PlayerViewModel.new()
	viewmodel.player = self  
	camera.add_child(viewmodel)
	
	var inter_script := load("res://src/Infrastructure/Player/VoxelInteractionComponent.gd") as GDScript
	if inter_script != null:
		interaction_component = inter_script.new() as Node3D
		interaction_component.set("player", self)
		interaction_component.set("world_controller", world_controller)
		camera.add_child(interaction_component)
	
	hud = PLAYER_HUD_SCENE.instantiate() as PlayerHUD
	hud.player = self
	hud.world_controller = world_controller
	add_child(hud)
	
	var parent_node := get_parent()
	if is_instance_valid(parent_node) and not parent_node.has_node("LoadingScreenCanvas/LoadingScreenOverlay"):
		hud.show_loading_screen()
		
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

	equipment_component = PlayerEquipmentComponent.new()
	add_child(equipment_component)
	equipment_component.initialize(self)


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if event.is_action_pressed("ui_cancel"):
		_handle_pause_trigger()
		return
		
	# Symmetrical Debugger: Press F10 in development to trigger a real storm instantly
	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_F10:
			var bootstrap := get_node_or_null("/root/Bootstrap")
			if is_instance_valid(bootstrap):
				var ws := bootstrap.get("weather_service") as Node
				if is_instance_valid(ws):
					var current: int = ws.get("current_weather") as int
					var target := 1 if current == 0 else 0
					ws.set("current_weather", target)
					ws.call("_trigger_climatological_overcast")
					print("[Developer Debug] Forced weather state to: ", "RAINY" if target == 1 else "SUNNY")
		
	if is_active and event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		var is_chat_key := (key_event.keycode == KEY_T or key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER)
		
		if is_chat_key and is_instance_valid(hud) and not hud.is_any_menu_open():
			get_viewport().set_input_as_handled()
			var chat := hud.chat_box
			if is_instance_valid(chat) and chat.has_method("_activate_typing_mode"):
				chat.call("_activate_typing_mode")


func _handle_pause_trigger() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		if is_instance_valid(hud) and hud.is_any_menu_open(): return
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if is_instance_valid(hud): hud.toggle_pause_menu(false)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if is_instance_valid(hud): hud.toggle_pause_menu(true)
		if is_instance_valid(world_controller) and world_controller.has_method("save_all"):
			world_controller.call("save_all")


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or not is_active or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
	if event is InputEventMouseMotion and is_instance_valid(camera):
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: 
			equipment_component.scroll_hotbar(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: 
			equipment_component.scroll_hotbar(1)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		var remote_flat_velocity := Vector2(velocity.x, velocity.z)
		if is_instance_valid(visual_component):
			visual_component.animate_movement(remote_flat_velocity, is_on_floor(), delta)
		return
	_process_local_player(delta)


func _process_local_player(delta: float) -> void:
	_process_cursor_grab_state()
	_rescue_player_from_void()
	
	if not is_active:
		_process_frozen_physics_movement(delta)
		return

	if is_instance_valid(equipment_component):
		equipment_component.process_hotbar_inputs(_input_component)
		
	_update_interactions_and_gamepad(delta)
	_evaluate_glider_deployment()

	if is_glider_deployed:
		_process_glider_physics(delta)
	else:
		_process_standard_movement(delta)

	move_and_slide()
	_apply_physics_effects(delta)
	
	RenderingServer.global_shader_parameter_set("player_position", global_position)


func _process_frozen_physics_movement(_delta: float) -> void:
	velocity = Vector3.ZERO


func _update_interactions_and_gamepad(delta: float) -> void:
	if is_instance_valid(interaction_component) and interaction_component.has_method("process_interaction"):
		interaction_component.call("process_interaction")

	if is_instance_valid(_input_component) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var pad_look := _input_component.get_gamepad_look_vector()
		if pad_look != Vector2.ZERO and is_instance_valid(camera):
			rotate_y(-pad_look.x * delta)
			camera.rotate_x(-pad_look.y * delta)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))


func _apply_physics_effects(delta: float) -> void:
	var current_flat_velocity := Vector2(velocity.x, velocity.z)
	if is_instance_valid(_camera_effects): _camera_effects.process_camera_effects(delta)
	if is_instance_valid(_footstep_player): _footstep_player.process_footsteps(delta, current_flat_velocity)
	if is_instance_valid(visual_component): visual_component.animate_movement(current_flat_velocity, is_on_floor(), delta)


func _evaluate_glider_deployment() -> void:
	if is_glider_deployed and GliderItemStrategy.evaluate_auto_retraction(is_on_floor(), is_on_wall()):
		is_glider_deployed = false
		_set_viewmodel_tool(PlayerViewModel.ToolType.NONE)
		if is_instance_valid(visual_component): visual_component.set_glider_wings_visible(false)
		return

	if not is_on_floor() and is_instance_valid(_input_component) and _input_component.is_jump_just_pressed():
		if is_instance_valid(inventory) and inventory.get_item_total_quantity(GLIDER_ITEM_ID) > 0:
			is_glider_deployed = not is_glider_deployed
			_set_viewmodel_tool(PlayerViewModel.ToolType.GLIDER if is_glider_deployed else PlayerViewModel.ToolType.NONE)
			if is_instance_valid(visual_component): visual_component.set_glider_wings_visible(is_glider_deployed)
			if is_glider_deployed: AudioService.play_sfx_static("loot_pickup")


func _process_glider_physics(delta: float) -> void:
	var wind_vector := Vector2.ZERO
	var wind_strength := 0.0
	var weather_node := get_parent().get_node_or_null("WeatherService")
	
	if is_instance_valid(weather_node):
		wind_vector = weather_node.get("_current_wind_vector") as Vector2
		wind_strength = weather_node.get("_current_wind_strength") as float

	var look_direction := -camera.global_transform.basis.z.normalized() if is_instance_valid(camera) else Vector3.FORWARD
	
	velocity = _glider_physics.calculate_glide_velocity(
		velocity, 
		look_direction, 
		wind_vector, 
		wind_strength, 
		global_position.y, 
		delta
	)

	var input_dir := _input_component.get_movement_vector() if is_instance_valid(_input_component) else Vector2.ZERO
	if input_dir.x != 0.0:
		rotate_y(-input_dir.x * 2.0 * delta)


func _process_standard_movement(delta: float) -> void:
	var is_in_liquid := _check_in_liquid_state()
	
	if not is_on_floor():
		var active_gravity := _get_active_gravity()
		var terminal := -8.0 if is_in_liquid else TERMINAL_VELOCITY
		velocity.y = max(velocity.y - active_gravity * delta, terminal)
			
	if is_instance_valid(_input_component) and _input_component.is_jump_just_pressed() and is_on_floor():
		velocity.y = JUMP_VELOCITY * (0.85 if is_in_liquid else 1.0)

	_apply_horizontal_movement(delta, is_in_liquid)


func _get_active_gravity() -> float:
	var active_gravity := gravity
	if is_instance_valid(GlitchRiftService.instance):
		var rift := GlitchRiftService.instance.get_active_rift_at(global_position)
		if rift != null: 
			active_gravity = rift.get_localized_gravity(gravity)
	return active_gravity


func _apply_horizontal_movement(delta: float, is_in_liquid: bool) -> void:
	var input_dir := _input_component.get_movement_vector() if is_instance_valid(_input_component) else Vector2.ZERO
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var current_flat_velocity := Vector2(velocity.x, velocity.z)
	
	var target_speed := SPEED * (0.6 if is_in_liquid else 1.0)
	var target_flat_velocity := Vector2(direction.x, direction.z) * target_speed
	
	var acceleration := 12.0 if is_on_floor() else (6.0 if not is_in_liquid else 4.0)
	current_flat_velocity = current_flat_velocity.lerp(target_flat_velocity, acceleration * delta)
	
	velocity.x = current_flat_velocity.x
	velocity.z = current_flat_velocity.y


func _set_viewmodel_tool(tool_id: PlayerViewModel.ToolType) -> void:
	if is_instance_valid(viewmodel): viewmodel.switch_to_tool(tool_id)


func take_damage(amount: int, knockback_force: Vector3) -> void:
	if not is_active or domain_entity.is_dead: return
	velocity += knockback_force
	domain_entity.take_damage(amount)


func _on_domain_entity_took_damage(_amount: int) -> void:
	if is_instance_valid(_camera_effects): _camera_effects.apply_trauma_shake(0.32)


func _on_domain_entity_died() -> void:
	domain_entity.health = 3
	domain_entity.is_dead = false
	is_active = false
	is_glider_deployed = false
	if is_instance_valid(visual_component): visual_component.set_glider_wings_visible(false)
	if is_instance_valid(hud): hud.show_loading_screen()
	position = Vector3(8.5, 14.0, 8.5)
	velocity = Vector3.ZERO
	if is_instance_valid(world_controller):
		world_controller.set("is_teleport_spawn", true)
		var ws: WorldState = world_controller.world_state
		if is_instance_valid(ws):
			world_controller.set("_target_spawn_chunk_pos", ws.global_to_chunk_pos(Vector3i(8, 0, 8)))


func _on_inventory_changed() -> void:
	if is_instance_valid(equipment_component):
		equipment_component.apply_hotbar_selection(active_slot_index)


func _rescue_player_from_void() -> void:
	if global_position.y >= -5.0: return
	velocity = Vector3.ZERO
	var block_x := floori(position.x)
	var block_z := floori(position.z)
	var found_safe_y: float = 14.0 
	if is_instance_valid(world_controller) and "world_state" in world_controller:
		var ws: WorldState = world_controller.world_state
		if is_instance_valid(ws): found_safe_y = ws.get_highest_solid_y(block_x, block_z)
	global_position.y = found_safe_y


func _process_cursor_grab_state() -> void:
	if not is_instance_valid(hud): return
	if Input.is_action_pressed("free_cursor"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if not hud.is_any_menu_open() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not Input.is_action_pressed("ui_cancel"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _check_in_liquid_state() -> bool:
	if is_instance_valid(world_controller) and "world_state" in world_controller:
		var ws: WorldState = world_controller.world_state
		if is_instance_valid(ws):
			var px := floori(global_position.x)
			var pz := floori(global_position.z)
			var feet_y := floori(global_position.y + 0.2)
			var chest_y := floori(global_position.y + 1.2)
			
			var f_block := ws.get_block(Vector3i(px, feet_y, pz))
			var c_block := ws.get_block(Vector3i(px, chest_y, pz))
			
			var def_f := BlockLibrary.get_definition(f_block) as BlockDefinition
			var def_c := BlockLibrary.get_definition(c_block) as BlockDefinition
			
			var is_f_liquid := def_f != null and def_f.is_liquid
			var is_c_liquid := def_c != null and def_c.is_liquid
			
			return is_f_liquid or is_c_liquid
	return false
