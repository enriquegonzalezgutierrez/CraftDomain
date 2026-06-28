# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure controller node representing the first-person player.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by delegating all voxel raycasting, mining, building,
#              eating, and NPC interactions to VoxelInteractionComponent.
#              STRICT MODE UPDATE: Replaced dynamic viewmodel and interaction 
#              injections with direct class instantiation. Cleaned up HUD creation
#              since the DialogueManager and LoadingScreen are now safely nested in PlayerHUD.
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

# STRICT MODE FIX: Statically typed Node references
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

# Camera Trauma Shake variable (Micro-Phase 4)
var _shake_intensity: float = 0.0

func _init() -> void:
	_setup_inputs_mouse_actions()
	
	# Instantiate pure domain model representing the player's survival/health logic
	domain_entity = VoxelEntity.new(3)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)

func _ready() -> void:
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
		"select_sword": KEY_8
	}
	
	for action_name in primary_inputs.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)
		
		var primary_event := InputEventKey.new()
		primary_event.keycode = primary_inputs[action_name]
		InputMap.action_add_event(action_name, primary_event)

func _setup_player_geometry() -> void:
	# 1. Collision Capsule
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
	
	# 3. Viewmodel Setup (STRICT MODE FIX: Direct class instantiation)
	viewmodel = PlayerViewModel.new()
	camera.add_child(viewmodel)

func _setup_hud() -> void:
	# Clean initialization, sub-widgets are now properly encapsulated in PlayerHUD
	inventory = InventoryComponent.new()
	hud = PlayerHUD.new()
	hud.name = "HUD"
	hud.player = self
	hud.world_controller = world_controller
	add_child(hud)
	
	_sync_hud_counters()

func _setup_interaction_component() -> void:
	print("[PlayerController] Initializing decoupled VoxelInteractionComponent (SRP)...")
	# STRICT MODE FIX: Direct class instantiation
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
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			if is_instance_valid(hud):
				hud.toggle_pause_menu(false)

func _unhandled_input(event: InputEvent) -> void:
	if not is_active or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
		
	# 1. Mouse Look
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))
		
	# 2. UX: Mouse Wheel Hotbar Scrolling
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_hotbar(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_hotbar(1)

func _physics_process(delta: float) -> void:
	if not is_active or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		velocity = Vector3.ZERO
		return

	_process_hotbar_keys()

	# Delegates all targeted raycasting, mining, building, and eating calculations
	if is_instance_valid(interaction_component):
		interaction_component.process_interaction()

	# Gravity & Jump
	if not is_on_floor():
		velocity.y -= gravity * delta
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
	_process_camera_effects(delta)

func _process_camera_effects(delta: float) -> void:
	if not is_instance_valid(camera):
		return
		
	var flat_vel := Vector2(velocity.x, velocity.z)
	var horizontal_speed := flat_vel.length()
	
	# Camera Bobbing (Vertical and Horizontal head sway)
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
	
	# High-frequency decaying damage camera trauma
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
	
	is_item_selected = (slot <= 5)
	
	match slot:
		0: active_build_type = BlockType.Type.STONE; _set_viewmodel_tool(PlayerViewModel.ToolType.PICKAXE)
		1: active_build_type = BlockType.Type.DIRT; _set_viewmodel_tool(PlayerViewModel.ToolType.PICKAXE)
		2: active_build_type = BlockType.Type.GRASS; _set_viewmodel_tool(PlayerViewModel.ToolType.PICKAXE)
		3: active_build_type = BlockType.Type.WOOD; _set_viewmodel_tool(PlayerViewModel.ToolType.SCROLL)
		4: active_build_type = BlockType.Type.LEAVES; _set_viewmodel_tool(PlayerViewModel.ToolType.SCROLL)
		5: active_build_type = BlockType.Type.LAVA; _set_viewmodel_tool(PlayerViewModel.ToolType.SCROLL)
		6: _set_viewmodel_tool(PlayerViewModel.ToolType.SCROLL)
		7: _set_viewmodel_tool(PlayerViewModel.ToolType.SWORD)

func _set_viewmodel_tool(tool_id: PlayerViewModel.ToolType) -> void:
	if is_instance_valid(viewmodel):
		viewmodel.switch_to_tool(tool_id)

func take_damage(amount: int, knockback_force: Vector3) -> void:
	if not is_active or domain_entity.is_dead: return
	velocity += knockback_force
	domain_entity.take_damage(amount)

func _on_domain_entity_took_damage(_amount: int) -> void:
	_shake_intensity = 0.32
	if is_instance_valid(hud):
		hud.update_health_display(domain_entity.health)
		if hud.has_method("flash_damage_screen"):
			hud.call("flash_damage_screen")

func _on_domain_entity_died() -> void:
	domain_entity.health = 3
	domain_entity.is_dead = false
	position = Vector3(8.5, 14.0, 8.5)
	velocity = Vector3.ZERO
	if is_instance_valid(hud):
		hud.update_health_display(domain_entity.health)

func _sync_hud_counters() -> void:
	if not is_instance_valid(hud) or not is_instance_valid(inventory): return
	var c := inventory as InventoryComponent
	for i in range(7):
		hud.update_slot_quantity(i, c.get_slot_item_name(i), inventory.get_slot_quantity(i))
	hud.update_slot_quantity(7, c.get_slot_item_name(7), -1)

func _setup_inputs_mouse_actions() -> void:
	var actions := {"click_left": MOUSE_BUTTON_LEFT, "click_right": MOUSE_BUTTON_RIGHT}
	for action in actions.keys():
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var btn_event := InputEventMouseButton.new()
		btn_event.button_index = actions[action]
		InputMap.action_add_event(action, btn_event)
		
		var key_event := InputEventKey.new()
		key_event.keycode = KEY_E if action == "click_left" else KEY_Q
		InputMap.action_add_event(action, key_event)
