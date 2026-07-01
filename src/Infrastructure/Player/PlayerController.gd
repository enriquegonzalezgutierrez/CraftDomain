# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure controller node representing the first-person player.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Delegates all voxel raycasting, 
#                mining, building, eating, and NPC interactions to VoxelInteractionComponent, 
#                and UI window orchestration to PlayerHUD.
#              - Open-Closed Principle (OCP): Dynamic inputs and key-mappings.
#              - OBSERVER PATTERN: Cleaned of obsolete UI-synchronization loops and 
#                unrelated keyboard UI input routings (SRP).
#              - Domain-Driven Design (DDD): Defers spatial height calculations to 
#                the WorldState Domain Aggregate, avoiding infrastructure domain leakage.
#              OPTIMIZATIONS:
#              - Restored the superior CapsuleShape3D for smooth voxel hill climbing.
#              - Configured floor_stop_on_slope and floor_snap_length within the correct
#                Godot 4 _ready() lifecycle to prevent edge sliding and sinking in GodotPhysics3D.
#              - Upgraded safe_margin to 0.015 to completely prevent voxel wall penetration
#                and wall-sticking/clipping bugs upon high-impact jumps.
#              - Configured wall_min_slide_angle to 0.0 to enable butter-smooth sliding along 
#                every voxel vertical wall, resolving corner sticking entirely.
#              - FIXED: Implemented a Safe Gravity Reset loop utilizing slide collision normals
#                to prevent infinite gravity accumulation (tunneling/void falling) on voxel edges.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Player/PlayerController.gd
# ==============================================================================
class_name PlayerController
extends CharacterBody3D

# Movement configurations
const SPEED: float = 6.0
const JUMP_VELOCITY: float = 6.5
const MOUSE_SENSITIVITY: float = 0.003

# Physics gravity
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Spawn Protection: Player remains frozen until home chunk is generated
var is_active: bool = false

# Domain Model Composition (DDD Compliance)
var domain_entity: VoxelEntity

# Segregated Inventory Interface (ISP compliant)
var inventory: IInventory

# STRICT TYPING: Statically typed Node references
var camera: Camera3D
var world_controller: Node3D
var hud: PlayerHUD
var viewmodel: PlayerViewModel
var interaction_component: VoxelInteractionComponent

# Build inventory selection state (0 to 7 matches our 8 slots)
var active_slot_index: int = 0
var active_build_type: BlockType.Type = BlockType.Type.STONE
var is_item_selected: bool = true # False if selecting currency/weapon

# Camera Bobbing & Tilt variables
var _bob_timer: float = 0.0
var _target_camera_pos: Vector3 = Vector3(0.0, 0.6, 0.0)
var _target_camera_tilt: float = 0.0

# Camera Trauma Shake variable
var _shake_intensity: float = 0.0

# Telemetry logging timer
var _telemetry_timer: float = 0.0


func _init() -> void:
	_setup_inputs_mouse_actions()
	
	# Instantiate pure domain model representing the player's survival/health logic
	domain_entity = VoxelEntity.new(3)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)


func _ready() -> void:
	# Configure advanced CharacterBody3D snapping properties (Godot 4 compliant)
	floor_stop_on_slope = true   # Completely prevents sliding off block edges/slopes
	floor_constant_speed = true  # Maintains speed consistency over steps
	floor_snap_length = 0.5      # Securely snaps capsule bottom to voxel surfaces
	
	# Upgraded safe margin to prevent penetration and sticking bugs on vertical walls
	safe_margin = 0.015
	
	# Enable butter-smooth sliding along vertical voxel walls even at extremely tight angles
	wall_min_slide_angle = 0.0

	_setup_inputs()
	_setup_player_geometry()
	_locate_world()
	_setup_hud()
	_setup_interaction_component() 
	
	# Capture mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _setup_inputs() -> void:
	var primary_inputs := {
		"move_forward": KEY_W,
		"move_backward": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"ui_cancel": KEY_ESCAPE,
		"select_stone": KEY_1,
		"select_dirt": KEY_2,
		"select_grass": KEY_3,
		"select_wood": KEY_4,
		"select_leaves": KEY_5,
		"select_lava": KEY_6,
		"select_chicken": KEY_7,
		"select_sword": KEY_8,
		"craft_item": KEY_C,
		"toggle_backpack": KEY_I,
		"free_cursor": KEY_ALT,
		"toggle_world_map": KEY_M 
	}
	
	for action_name in primary_inputs.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)
		
		var primary_event := InputEventKey.new()
		primary_event.keycode = primary_inputs[action_name] as Key
		InputMap.action_add_event(action_name, primary_event)


func _setup_player_geometry() -> void:
	# 1. Collision Capsule (Restored for flawless stairs and voxel hill climbing)
	var collision := CollisionShape3D.new()
	collision.name = "PlayerCollision"
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.4
	capsule_shape.height = 1.8
	collision.shape = capsule_shape
	add_child(collision)
	
	# 2. Camera setup positioned at eye-level
	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.position = Vector3(0, 0.6, 0)
	camera.current = true
	add_child(camera)
	
	# 3. Viewmodel Setup
	viewmodel = PlayerViewModel.new()
	camera.add_child(viewmodel)


func _setup_hud() -> void:
	inventory = InventoryComponent.new()
	hud = PlayerHUD.new()
	hud.name = "HUD"
	hud.player = self
	hud.world_controller = world_controller
	add_child(hud)


func _setup_interaction_component() -> void:
	print("[PlayerController] Initializing decoupled VoxelInteractionComponent (SRP)...")
	interaction_component = VoxelInteractionComponent.new()
	
	# Inject dependencies (DIP compliant)
	interaction_component.player = self
	interaction_component.camera = camera
	interaction_component.world_controller = world_controller
	interaction_component.hud = hud
	
	camera.add_child(interaction_component)
	print("[PlayerController] VoxelInteractionComponent successfully connected.")


func _locate_world() -> void:
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		world_controller = parent_node.get_node_or_null("World") as Node3D


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if is_instance_valid(hud):
				hud.toggle_pause_menu(true)
			if is_instance_valid(world_controller) and world_controller.has_method("save_all"):
				world_controller.call("save_all")
		else:
			# Safeguard: Let active workshops/inventories capture Escape first
			if is_instance_valid(hud) and (hud.get("_crafting_overlay") != null or hud.get("_inventory_overlay") != null or hud.get("_world_map_overlay") != null):
				return
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			if is_instance_valid(hud):
				hud.toggle_pause_menu(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
		
	# 1. Mouse Gaze Look Rotation
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))
		
	# 2. Mouse Wheel Hotbar Scrolling
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_hotbar(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_hotbar(1)


func _physics_process(delta: float) -> void:
	# Controls hardware cursor visibility when holding Left Alt
	_process_cursor_grab_state()

	# Telemetry Diagnostics
	_telemetry_timer += delta
	if _telemetry_timer >= 1.0:
		_telemetry_timer = 0.0
		_print_physics_telemetry()

	# ---> VOID RESCUE FAILSAFE SHIELD <---
	if global_position.y < 2.0:
		_rescue_player_from_void()

	# Freeze player movement inputs if spawn protection is active (SRP compliant)
	if not is_active:
		return

	_process_hotbar_keys()

	# Delegates all targeted raycasting, mining, building, and eating calculations
	if is_instance_valid(interaction_component):
		interaction_component.process_interaction()

	# Gravity & Jump (Snaps back to 0 on floor automatically due to SNAP configuration)
	if not is_on_floor():
		velocity.y -= gravity * delta
		# Limit terminal falling velocity to prevent geometry clipping/tunneling bugs
		if velocity.y < -20.0:
			velocity.y = -20.0
			
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement Calculations
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction != Vector3.ZERO:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
	# FIXED: Prevent infinite gravity accumulation (and tunneling) when stuck on voxel edges/corners (Godot 4 bug)
	if get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var collision := get_slide_collision(i)
			if collision.get_normal().y > 0.5:
				# The player capsule is resting on a floor-like surface
				if velocity.y < 0.0:
					velocity.y = 0.0
				break
				
	_process_camera_effects(delta)


## High-precision telemetry logger tracing physics engine states and raw inputs.
func _print_physics_telemetry() -> void:
	var raw_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	print("[Physics Telemetry] Pos: %s | Vel: %s | On Floor: %s | Active: %s | Hardware Input: %s" % [
		global_position, velocity, is_on_floor(), is_active, raw_input
	])


## Scan downwards using Domain Rules to rescue player back to the surface of the topmost solid block
func _rescue_player_from_void() -> void:
	print("[Physics Telemetry WARNING] Player fell into the void! Position: %s. Relocalizing to surface..." % global_position)
	velocity = Vector3.ZERO
	
	var block_x := floori(global_position.x)
	var block_z := floori(global_position.z)
	var found_safe_y: float = 14.0 # Default fallback
	
	var world_ctrl := world_controller as WorldController
	if is_instance_valid(world_ctrl) and is_instance_valid(world_ctrl.world_state):
		# Centralized Domain Rule calculation (DDD compliant, SRP compliant)
		found_safe_y = world_ctrl.world_state.get_highest_solid_y(block_x, block_z)
		
	global_position.y = found_safe_y


## Controls hardware cursor visibility when holding Left Alt
func _process_cursor_grab_state() -> void:
	if not is_instance_valid(hud):
		return
		
	# If Alt is held, release the cursor so the player can hover/click the HUD
	if Input.is_action_pressed("free_cursor"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		# Only recapture mouse if NO other UI overlay/pause menu is open!
		if not hud.is_any_menu_open():
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not Input.is_action_pressed("ui_cancel"):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Executes procedural camera movements (bobbing/sway) and damage camera trauma
func _process_camera_effects(delta: float) -> void:
	if not is_instance_valid(camera):
		return
		
	var flat_vel := Vector2(velocity.x, velocity.z)
	var horizontal_speed := flat_vel.length()
	
	# Camera Bobbing
	if is_on_floor() and horizontal_speed > 0.1:
		_bob_timer += delta * horizontal_speed * 2.2
		var bob_y: float = sin(_bob_timer) * 0.035
		var bob_x: float = cos(_bob_timer * 0.5) * 0.018
		_target_camera_pos = Vector3(bob_x, 0.6 + bob_y, 0.0)
		
		var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		_target_camera_tilt = -input_dir.x * 0.02
	else:
		_bob_timer += delta * 1.5
		var breath_y: float = sin(_bob_timer) * 0.006
		_target_camera_pos = Vector3(0.0, 0.6 + breath_y, 0.0)
		_target_camera_tilt = 0.0
		
	var current_pos: Vector3 = camera.position.lerp(_target_camera_pos, delta * 10.0)
	var current_tilt: float = lerp(camera.rotation.z, _target_camera_tilt, delta * 8.0)
	
	# Camera Trauma Shake
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


## Decoupled contextual Hotbar selection mapping
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
		return
		
	var item_id := slot_data.item_id
	
	if item_id >= 1 and item_id <= 15:
		is_item_selected = true
		active_build_type = item_id as BlockType.Type
		
		if item_id == 15: 
			_set_viewmodel_tool(PlayerViewModel.ToolType.SCROLL)
		else:
			_set_viewmodel_tool(PlayerViewModel.ToolType.PICKAXE)
	else:
		is_item_selected = false
		active_build_type = BlockType.Type.AIR
		
		if item_id == 16: 
			_set_viewmodel_tool(PlayerViewModel.ToolType.SCROLL)
		elif item_id == 17: 
			_set_viewmodel_tool(PlayerViewModel.ToolType.SWORD)
		else:
			_set_viewmodel_tool(PlayerViewModel.ToolType.NONE)


func _set_viewmodel_tool(tool_id: PlayerViewModel.ToolType) -> void:
	if is_instance_valid(viewmodel):
		viewmodel.switch_to_tool(tool_id)


func take_damage(amount: int, knockback_force: Vector3) -> void:
	if not is_active or domain_entity.is_dead: return
	velocity += knockback_force
	domain_entity.take_damage(amount)


func _on_domain_entity_took_damage(_amount: int) -> void:
	_shake_intensity = 0.32


## Reactive health reset on player death.
func _on_domain_entity_died() -> void:
	domain_entity.health = 3
	domain_entity.is_dead = false
	
	# Freeze physics and display the loading screen before respawning!
	is_active = false
	if is_instance_valid(hud):
		hud.show_loading_screen()
		
	position = Vector3(8.5, 14.0, 8.5)
	velocity = Vector3.ZERO
	
	# Re-track and reload starting chunks coordinates safely
	if is_instance_valid(world_controller):
		var chunk_pos: Vector3i = world_controller.get("world_state").global_to_chunk_pos(Vector3i(8, 0, 8))
		world_controller.set("_target_spawn_chunk_pos", chunk_pos)


func _setup_inputs_mouse_actions() -> void:
	if not InputMap.has_action("click_left"):
		InputMap.add_action("click_left")
	InputMap.action_erase_events("click_left")
	
	var left_btn := InputEventMouseButton.new()
	left_btn.button_index = MOUSE_BUTTON_LEFT 
	InputMap.action_add_event("click_left", left_btn)
	
	var left_key := InputEventKey.new()
	left_key.keycode = KEY_E
	InputMap.action_add_event("click_left", left_key)
	
	if not InputMap.has_action("click_right"):
		InputMap.add_action("click_right")
	InputMap.action_erase_events("click_right")
	
	var right_btn := InputEventMouseButton.new()
	right_btn.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("click_right", right_btn)
	
	var right_key := InputEventKey.new()
	right_key.keycode = KEY_Q
	InputMap.action_add_event("click_right", right_key)
