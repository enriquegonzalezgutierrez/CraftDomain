# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure controller node representing the first-person player.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by delegating all voxel raycasting, mining, building,
#              eating, and NPC interactions to VoxelInteractionComponent.
#              Acts strictly as a lightweight Movement and Camera Controller.
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

# Node references created via code
var camera: Camera3D
var world_controller: Node3D
var hud: PlayerHUD
var viewmodel: Node3D

# Decoupled SRP managers and components
var dialogue_manager: Node 
var interaction_component: VoxelInteractionComponent # Decoupled SRP interaction handler

# Build inventory selection state (0 to 7 matches our 8 slots)
var active_slot_index: int = 0
var active_build_type: BlockType.Type = BlockType.Type.STONE
var is_item_selected: bool = true # False if selecting currency/weapon

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
	_setup_interaction_component() # Instantiate and wire the decoupled interaction handler (SRP)
	
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
	
	# 3. Viewmodel Setup
	var viewmodel_script: Script = load("res://src/Infrastructure/Player/PlayerViewModel.gd")
	viewmodel = viewmodel_script.new() as Node3D
	camera.add_child(viewmodel)

func _setup_hud() -> void:
	# 1. Instantiate the decoupled DialogueManager to satisfy SOLID SRP
	var dm_script: Script = load("res://src/Infrastructure/Dialogue/DialogueManager.gd")
	if dm_script != null:
		dialogue_manager = dm_script.new() as Node
		dialogue_manager.name = "DialogueManager"
		dialogue_manager.set("player", self)
		add_child(dialogue_manager)
		
	# 2. Setup standard inventory & HUD
	inventory = InventoryComponent.new()
	hud = PlayerHUD.new()
	hud.name = "HUD"
	hud.player = self
	hud.world_controller = world_controller
	add_child(hud)
	
	# 3. Instantiate the decoupled, standalone LoadingScreen dynamically
	var ls_script: Script = load("res://src/Infrastructure/UI/LoadingScreen.gd")
	if ls_script != null:
		var loading_screen = ls_script.new(self) as Node
		hud.add_child(loading_screen) 
		
	_sync_hud_counters()

## Instantiates and registers the decoupled interaction component as a child of the camera (SRP)
func _setup_interaction_component() -> void:
	print("[PlayerController] Initializing decoupled VoxelInteractionComponent (SRP)...")
	var ic_script: Script = load("res://src/Infrastructure/Player/VoxelInteractionComponent.gd")
	if ic_script != null:
		interaction_component = ic_script.new() as VoxelInteractionComponent
		
		# Inject dependencies (DIP compliant)
		interaction_component.player = self
		interaction_component.camera = camera
		interaction_component.world_controller = world_controller
		interaction_component.hud = hud
		
		# Added as a child of the camera so its internal RayCast3D rotates automatically with player gaze
		camera.add_child(interaction_component)
		print("[PlayerController] VoxelInteractionComponent successfully connected.")

func _locate_world() -> void:
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		world_controller = parent_node.get_node_or_null("World")

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

	# --- SOLID DELEGATION ---
	# Delegates all targeted raycasting, mining, building, and eating calculations
	# to the decoupled specialized VoxelInteractionComponent (SRP)
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

func _scroll_hotbar(direction: int) -> void:
	var new_slot := active_slot_index + direction
	if new_slot > 7:
		new_slot = 0
	elif new_slot < 0:
		new_slot = 7
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
	
	# Slot 0 to 5 are buildable blocks (Includes Lava Bucket!)
	is_item_selected = (slot <= 5)
	
	match slot:
		0: active_build_type = BlockType.Type.STONE; _set_viewmodel_tool(2)
		1: active_build_type = BlockType.Type.DIRT; _set_viewmodel_tool(2)
		2: active_build_type = BlockType.Type.GRASS; _set_viewmodel_tool(2)
		3: active_build_type = BlockType.Type.WOOD; _set_viewmodel_tool(1)
		4: active_build_type = BlockType.Type.LEAVES; _set_viewmodel_tool(1)
		5: active_build_type = BlockType.Type.LAVA; _set_viewmodel_tool(1)
		6: _set_viewmodel_tool(1)
		7: _set_viewmodel_tool(3)

func _set_viewmodel_tool(tool_id: int) -> void:
	if is_instance_valid(viewmodel) and viewmodel.has_method("switch_to_tool"):
		viewmodel.call("switch_to_tool", tool_id)

func take_damage(amount: int, knockback_force: Vector3) -> void:
	if not is_active or domain_entity.is_dead: return
	velocity += knockback_force
	domain_entity.take_damage(amount)

func _on_domain_entity_took_damage(_amount: int) -> void:
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
