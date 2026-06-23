# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure controller node representing the first-person player, 
#              handling camera look, movements, RayCast targeting, inventory,
#              and animated first-person 3D viewmodel tool-swapping.
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

# Player Survival Combat Health
var health: int = 3

# Segregated Inventory Interface (ISP compliant)
var inventory: IInventory

# Node references created via code (loosely typed to prevent compile-time loops)
var camera: Camera3D
var raycast: RayCast3D
var world_controller: Node3D
var hud: PlayerHUD
var viewmodel: Node3D

# Build inventory selection state (0 to 7 matches our 8 slots)
var active_slot_index: int = 0
var active_build_type: BlockType.Type = BlockType.Type.STONE
var is_item_selected: bool = true # False if selecting currency/weapon

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
		"select_grass": KEY_3,
		"select_wood": KEY_4,
		"select_leaves": KEY_5,
		"select_lava": KEY_6,
		"select_chicken": KEY_7,
		"select_sword": KEY_8
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
	
	# 4. First-Person Animated Viewmodel setup (loosely typed to prevent compile locks)
	var viewmodel_script: Script = load("res://src/Infrastructure/Player/PlayerViewModel.gd")
	viewmodel = viewmodel_script.new() as Node3D
	camera.add_child(viewmodel)
	
	# Initial safe spawn altitude (to fall onto the generated chunk)
	position = Vector3(8.0, 16.0, 8.0)

func _setup_hud() -> void:
	# Instantiate concrete inventory manager component (SRP compliant)
	inventory = InventoryComponent.new()
	
	# Instantiate and initialize the HUD node
	hud = PlayerHUD.new()
	hud.name = "HUD"
	hud.player = self
	hud.world_controller = world_controller
	add_child(hud)
	
	# Sync starting HUD displays
	_sync_hud_counters()

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

	# Mouse lock & Auto-save handling
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			
			# Dynamic Auto-Save: Silently write player position and all world modifications to disk
			if is_instance_valid(world_controller) and world_controller.has_method("save_all"):
				world_controller.call("save_all")
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			# Hide the Pause Menu overlay
			if is_instance_valid(hud):
				hud.toggle_pause_menu(false)

	# Quick Slot Selection mapping keys 1-8 directly to modern Hotbar Slots 0-7
	# Dynamic Tool Swapping: 1=Scroll, 2=Pickaxe, 3=Sword
	if Input.is_action_just_pressed("select_stone"):
		active_slot_index = 0
		active_build_type = BlockType.Type.STONE
		is_item_selected = true
		hud.update_active_slot(0)
		_set_viewmodel_tool(2) # Stone -> Pickaxe
	elif Input.is_action_just_pressed("select_dirt"):
		active_slot_index = 1
		active_build_type = BlockType.Type.DIRT
		is_item_selected = true
		hud.update_active_slot(1)
		_set_viewmodel_tool(2) # Dirt -> Pickaxe
	elif Input.is_action_just_pressed("select_grass"):
		active_slot_index = 2
		active_build_type = BlockType.Type.GRASS
		is_item_selected = true
		hud.update_active_slot(2)
		_set_viewmodel_tool(2) # Grass -> Pickaxe
	elif Input.is_action_just_pressed("select_wood"):
		active_slot_index = 3
		is_item_selected = true
		hud.update_active_slot(3)
		_set_viewmodel_tool(1) # Wood -> Scroll (Blueprint)
	elif Input.is_action_just_pressed("select_leaves"):
		active_slot_index = 4
		is_item_selected = true
		hud.update_active_slot(4)
		_set_viewmodel_tool(1) # Leaves -> Scroll (Blueprint)
	elif Input.is_action_just_pressed("select_lava"):
		active_slot_index = 5
		is_item_selected = false
		hud.update_active_slot(5)
		_set_viewmodel_tool(1) # Lava -> Scroll (Blueprint)
	elif Input.is_action_just_pressed("select_chicken"):
		active_slot_index = 6
		is_item_selected = false
		hud.update_active_slot(6)
		_set_viewmodel_tool(1) # Chicken -> Scroll (Blueprint)
	elif Input.is_action_just_pressed("select_sword"):
		active_slot_index = 7
		is_item_selected = false
		hud.update_active_slot(7)
		_set_viewmodel_tool(3) # Sword -> Handheld Sword

	# Block Mining & Placement Handlers
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and is_instance_valid(world_controller):
		if Input.is_action_just_pressed("click_left"):
			_mine_or_attack()
		elif Input.is_action_just_pressed("click_right"):
			_build_or_interact()

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

func _set_viewmodel_tool(tool_id: int) -> void:
	if is_instance_valid(viewmodel) and viewmodel.has_method("switch_to_tool"):
		viewmodel.call("switch_to_tool", tool_id)

func _trigger_viewmodel_swing() -> void:
	if is_instance_valid(viewmodel) and viewmodel.has_method("play_swing_animation"):
		viewmodel.call("play_swing_animation")

func _mine_or_attack() -> void:
	_trigger_viewmodel_swing() # Trigger dynamic 3D swing animation
	
	if not raycast.is_colliding():
		return
		
	var collider = raycast.get_collider()
	
	# 1. LSP Polymorphic Combat check: If holding the Sword (Slot 7) and targeting any entity, strike it!
	if active_slot_index == 7 and is_instance_valid(collider):
		if collider is VoxelEntity:
			# Calculate directional knockback away from the camera heading
			var knockback_dir: Vector3 = -camera.global_transform.basis.z.normalized() * 5.5
			knockback_dir.y = 2.5 # Lift them upward slightly
			
			collider.take_damage(1, knockback_dir)
			return # Bypass mining

	# 2. Mining check (Standard block breaking)
	if is_instance_valid(world_controller):
		var hit_pos: Vector3 = raycast.get_collision_point() - (raycast.get_collision_normal() * 0.1)
		var block_coord := Vector3i(floor(hit_pos.x), floor(hit_pos.y), floor(hit_pos.z))
		
		# Query what block type we are breaking to collect it
		var world_state = world_controller.get("world_state")
		if is_instance_valid(world_state) and world_state.has_method("get_block"):
			var mined_block_type: BlockType.Type = world_state.call("get_block", block_coord)
			
			# Collect and add to inventory counts (ISP check)
			if inventory is InventoryComponent:
				(inventory as InventoryComponent).add_block_by_type(mined_block_type)
				_sync_hud_counters()
				print("[Inventory] Gathered 1: ", BlockType.Type.keys()[mined_block_type])
		
		# Replace with Air
		world_controller.call("set_block_globally", block_coord, BlockType.Type.AIR)
		print("[Player] Mined block at: ", block_coord)

func _build_or_interact() -> void:
	_trigger_viewmodel_swing() # Trigger dynamic 3D swing animation
	
	if not raycast.is_colliding():
		return
		
	var collider = raycast.get_collider()
	
	# 1. LSP Polymorphic Interaction check: If targeting a VoxelEntity, trigger transaction
	if is_instance_valid(collider) and collider is VoxelEntity:
		collider.interact(self)
		_sync_hud_counters()
		return # Bypass placement/eating
		
	# 2. Eating check: If holding Fried Chicken (Slot 6), eat 1 to restore 1 full heart
	if active_slot_index == 6 and is_instance_valid(inventory):
		if inventory.can_modify_slot_quantity(6, -1) and health < 3:
			inventory.modify_slot_quantity(6, -1)
			health += 1
			
			# Update HUD
			hud.update_health_display(health)
			_sync_hud_counters()
			print("[Player] Crunch munch! Consumed 1 Fried Chicken. Restored 1 Heart. HP: ", health)
		return

	# 3. Block placement check (Only if holding slot 0-4 and counts > 0)
	if is_item_selected and is_instance_valid(world_controller) and is_instance_valid(inventory):
		var inventory_comp := inventory as InventoryComponent
		var build_type: BlockType.Type = inventory_comp.get_slot_build_type(active_slot_index)
		
		if not inventory.can_modify_slot_quantity(active_slot_index, -1):
			print("[Player] Out of blocks for: ", inventory_comp.get_slot_item_name(active_slot_index))
			return
			
		var build_pos: Vector3 = raycast.get_collision_point() + (raycast.get_collision_normal() * 0.1)
		var block_coord := Vector3i(floor(build_pos.x), floor(build_pos.y), floor(build_pos.z))
		
		# Do not place blocks inside the player's physical feet/body bounds
		var player_feet_coord := Vector3i(floor(position.x), floor(position.y), floor(position.z))
		var player_head_coord := Vector3i(floor(position.x), floor(position.y + 0.9), floor(position.z))
		
		if block_coord == player_feet_coord or block_coord == player_head_coord:
			return # Avoid self-clipping
			
		# Deduct and place using the abstract IInventory interface
		inventory.modify_slot_quantity(active_slot_index, -1)
		_sync_hud_counters()
		
		world_controller.call("set_block_globally", block_coord, build_type)
		print("[Player] Placed block at: ", block_coord)

## Public Combat API: Called by hostile zombies to deal damage and knock the player back.
func take_damage(amount: int, knockback_force: Vector3) -> void:
	if not is_active:
		return
		
	health -= amount
	print("[Player] Ouch! Took damage! HP remaining: ", health)
	
	# Apply knockback thrust
	velocity += knockback_force
	
	# Update UI hearts display
	if is_instance_valid(hud):
		hud.update_health_display(health)
		
	if health <= 0:
		_die_and_respawn()

func _die_and_respawn() -> void:
	print("[Player] You died! Respawning at home coordinates...")
	
	# Reset state
	health = 3
	position = Vector3(8.5, 14.0, 8.5) # Safe spawn height
	velocity = Vector3.ZERO
	
	# Restore HUD display
	if is_instance_valid(hud):
		hud.update_health_display(health)

## Public Inventory Synchronizer (ISP & DIP compliant): Writes values cleanly to the HUD
func _sync_hud_counters() -> void:
	if not is_instance_valid(hud):
		return
		
	# Synchronize all 8 quick-slots counters directly with the HUD
	var comp := inventory as InventoryComponent
	hud.update_slot_quantity(0, comp.get_slot_item_name(0), inventory.get_slot_quantity(0))
	hud.update_slot_quantity(1, comp.get_slot_item_name(1), inventory.get_slot_quantity(1))
	hud.update_slot_quantity(2, comp.get_slot_item_name(2), inventory.get_slot_quantity(2))
	hud.update_slot_quantity(3, comp.get_slot_item_name(3), inventory.get_slot_quantity(3))
	hud.update_slot_quantity(4, comp.get_slot_item_name(4), inventory.get_slot_quantity(4))
	hud.update_slot_quantity(5, comp.get_slot_item_name(5), inventory.get_slot_quantity(5))
	hud.update_slot_quantity(6, comp.get_slot_item_name(6), inventory.get_slot_quantity(6))
	hud.update_slot_quantity(7, comp.get_slot_item_name(7), -1) # -1 hides the numeric counter for the sword

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
		
		# Bind Mouse Button Click
		var click_event := InputEventMouseButton.new()
		click_event.button_index = mouse_actions[action]
		InputMap.action_add_event(action, click_event)
		
		# Bind secondary keyboard equivalents (E/Q) to act exactly like mouse clicks (Anti-Spam)
		var key_event := InputEventKey.new()
		key_event.keycode = KEY_E if action == "click_left" else KEY_Q
		InputMap.action_add_event(action, key_event)

# Call the helper directly inside the constructor/setup chain
func _init() -> void:
	_setup_inputs_mouse_actions()
