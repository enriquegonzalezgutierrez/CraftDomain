# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure controller node representing the first-person player, 
#              handling camera look, movements, RayCast targeting, inventory counts,
#              and dynamic communication with the PlayerHUD hotbar selector.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Player/PlayerController.gd
# ==============================================================================
class_name PlayerController
extends CharacterBody3D

# Movement configurations
const SPEED: float = 6.0
const JUMP_VELOCITY: float = 6.5
const MOUSE_SENSITIVITY: float = 0.003
const REACH_DISTANCE: float = 5.0

# Physics gravity
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Spawn Protection: Player remains frozen until home chunk is generated
var is_active: bool = false

# Player Inventory Currency (Trading)
var lava_buckets: int = 3
var fried_chickens: int = 0

# Node references created via code
var camera: Camera3D
var raycast: RayCast3D
var world_controller: WorldController
var hud: PlayerHUD

# Build inventory selection state
var active_build_type: BlockType.Type = BlockType.Type.STONE
var is_item_selected: bool = true # False if selecting currency

# Internal rotation tracking
var _rotation_input: Vector2 = Vector2.ZERO

func _ready() -> void:
	_setup_inputs()
	_setup_player_geometry()
	_locate_world()
	_setup_hud()
	
	# Capture mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_inputs() -> void:
	# Action registration setup mapped to both WASD and Arrow Keys
	var primary_inputs := {
		"move_forward": KEY_W,
		"move_backward": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"ui_cancel": KEY_ESCAPE,
		"select_stone": KEY_1,
		"select_dirt": KEY_2,
		"select_wood": KEY_3,
		"select_leaves": KEY_4,
		"select_lava": KEY_5,
		"select_chicken": KEY_6
	}
	
	var secondary_inputs := {
		"move_forward": KEY_UP,
		"move_backward": KEY_DOWN,
		"move_left": KEY_LEFT,
		"move_right": KEY_RIGHT
	}
	
	# Register inputs
	for action_name in primary_inputs.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		
		InputMap.action_erase_events(action_name)
		
		var primary_event := InputEventKey.new()
		primary_event.keycode = primary_inputs[action_name]
		InputMap.action_add_event(action_name, primary_event)
		
		if secondary_inputs.has(action_name):
			var secondary_event := InputEventKey.new()
			secondary_event.keycode = secondary_inputs[action_name]
			InputMap.action_add_event(action_name, secondary_event)

func _setup_player_geometry() -> void:
	# 1. Collision Capsule
	var collision := CollisionShape3D.new()
	collision.name = "PlayerCollision"
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.4
	capsule_shape.height = 1.8
	collision.shape = capsule_shape
	add_child(collision)
	
	# 2. Camera setup positioned at eye-level (1.6 meters)
	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.position = Vector3(0, 0.6, 0)
	camera.current = true
	add_child(camera)
	
	# 3. Dynamic target selection raycast
	raycast = RayCast3D.new()
	raycast.name = "MiningRayCast"
	raycast.target_position = Vector3(0, 0, -REACH_DISTANCE)
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true
	camera.add_child(raycast)
	
	# Initial safe spawn altitude (to fall onto the generated chunk)
	position = Vector3(8.0, 16.0, 8.0)

func _setup_hud() -> void:
	# Instantiate and initialize the HUD node
	hud = PlayerHUD.new()
	hud.name = "HUD"
	hud.player = self
	hud.world_controller = world_controller
	add_child(hud)

func _locate_world() -> void:
	# Clean dependency lookup of sibling nodes
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		world_controller = parent_node.get_node_or_null("World")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotation_input -= event.relative * MOUSE_SENSITIVITY

func _physics_process(delta: float) -> void:
	# Keep player frozen in place until activated by the WorldController
	if not is_active:
		velocity = Vector3.ZERO
		return

	# Mouse lock handling
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Quick Slot Selection mapping keys 1-6 directly to modern Hotbar Slots 0-5
	if Input.is_action_just_pressed("select_stone"):
		active_build_type = BlockType.Type.STONE
		is_item_selected = true
		hud.update_active_slot(0)
	elif Input.is_action_just_pressed("select_dirt"):
		active_build_type = BlockType.Type.DIRT
		is_item_selected = true
		hud.update_active_slot(1)
	elif Input.is_action_just_pressed("select_wood"):
		active_build_type = BlockType.Type.WOOD
		is_item_selected = true
		hud.update_active_slot(3) # Mapping Wood to slot 3
	elif Input.is_action_just_pressed("select_leaves"):
		active_build_type = BlockType.Type.LEAVES
		is_item_selected = true
		hud.update_active_slot(4) # Mapping Leaves to slot 4
	elif Input.is_action_just_pressed("select_lava"):
		is_item_selected = false
		hud.update_active_slot(5) # Mapping Lava to slot 5 (inventory coin slot)
	elif Input.is_action_just_pressed("select_chicken"):
		is_item_selected = false
		hud.update_active_slot(6) # Mapping Chicken to slot 6 (inventory coin slot)

	# Block Mining & Placement Handlers
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and is_instance_valid(world_controller):
		if Input.is_action_just_pressed("click_left") or Input.is_key_pressed(KEY_E): # Left mouse or 'E' key
			_mine_block()
		elif Input.is_action_just_pressed("click_right") or Input.is_key_pressed(KEY_Q): # Right mouse or 'Q' key
			_build_block()

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Look Rotation
	rotate_y(_rotation_input.x)
	camera.rotate_x(_rotation_input.y)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	_rotation_input = Vector2.ZERO

	# Movement direction
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction != Vector3.ZERO:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _mine_block() -> void:
	if raycast.is_colliding():
		# Get collision vector and step slightly inside the block surface to find its center
		var hit_pos: Vector3 = raycast.get_collision_point() - (raycast.get_collision_normal() * 0.1)
		var block_coord := Vector3i(floor(hit_pos.x), floor(hit_pos.y), floor(hit_pos.z))
		
		# Replace with Air
		world_controller.set_block_globally(block_coord, BlockType.Type.AIR)
		print("[Player] Mined block at: ", block_coord)

func _build_block() -> void:
	if raycast.is_colliding():
		# Clean interaction routing: If the targeted collider is an interactive Entity, trigger transaction
		var collider = raycast.get_collider()
		if collider is PassiveEntity:
			collider.interact(self)
			return # Bypass block placement
			
		# Avoid placing blocks if selecting currency items
		if not is_item_selected:
			return
			
		# Get collision vector and step slightly outside the block surface to find the open position
		var build_pos: Vector3 = raycast.get_collision_point() + (raycast.get_collision_normal() * 0.1)
		var block_coord := Vector3i(floor(build_pos.x), floor(build_pos.y), floor(build_pos.z))
		
		# Do not place blocks inside the player's physical feet/body bounds
		var player_feet_coord := Vector3i(floor(position.x), floor(position.y), floor(position.z))
		var player_head_coord := Vector3i(floor(position.x), floor(position.y + 0.9), floor(position.z))
		
		if block_coord == player_feet_coord or block_coord == player_head_coord:
			return # Avoid self-clipping
			
		world_controller.set_block_globally(block_coord, active_build_type)
		print("[Player] Placed block at: ", block_coord)

# Handle Left-Click/Right-Click action maps dynamically
func _setup_inputs_mouse_actions() -> void:
	var mouse_actions := {
		"click_left": MOUSE_BUTTON_LEFT,
		"click_right": MOUSE_BUTTON_RIGHT
	}
	for action in mouse_actions.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var click_event := InputEventMouseButton.new()
		click_event.button_index = mouse_actions[action]
		InputMap.action_add_event(action, click_event)

# Call the helper directly inside the constructor/setup chain
func _init() -> void:
	_setup_inputs_mouse_actions()
