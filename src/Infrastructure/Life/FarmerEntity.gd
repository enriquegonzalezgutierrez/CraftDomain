# ==============================================================================
# Project: CraftDomain
# Description: Farmer NPC entity. Inherits from the abstract base class PassiveEntity.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles only the farming-specific
#                AI states, dialogues, and agriculturist visual blocks.
#              - Liskov Substitution Principle (LSP): Fully interchangeable subclass.
#              FASE A UPGRADE:
#              - Implements autonomous volumetric crop scanning (7x3x7 blocks).
#              - Implements physical pathfinding lock-on and walking towards ripe crops.
#              - Implements automated harvesting and perpetual replanting of seeds.
#              STRICT TYPING: Upgraded to direct static method calls instead of .call().
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/FarmerEntity.gd
# ==============================================================================
class_name FarmerEntity
extends PassiveEntity

# Agricultural AI scanning trackers
var _scan_timer: float = 3.0
var _target_crop_coord := Vector3i(0, -999, 0)
var _harvest_timer: float = 0.0

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1)
	name = "Entity_FARMER"

## Override: Assembles the 3D Farmer model with its rustic field outfit
func _build_visual_representation() -> void:
	var shirt_color := Color(0.85, 0.82, 0.75)       # Linen off-white shirt
	var denim_color := Color(0.20, 0.35, 0.55)       # Rustic blue denim overalls
	var strap_color := Color(0.35, 0.22, 0.15)       # Brown leather straps
	var skin_color := Color(0.95, 0.75, 0.65)        # Peachy skin
	var nose_color := Color(0.85, 0.65, 0.55)        # Nose
	var straw_color := Color(0.88, 0.78, 0.42)       # Straw yellow hat
	var boots_color := Color(0.18, 0.14, 0.11)       # Muddy boots
	var iron_color := Color(0.50, 0.50, 0.52)        # Worn iron blade
	
	# 1. Base Legs / Muddy Boots (Attached to the bouncing bob node!)
	_create_box(_body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), boots_color)
	
	# 2. Torso: Linen Shirt & Denim Overalls
	_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), shirt_color)
	_create_box(_body_bob_node, Vector3(0.47, 0.45, 0.47), Vector3(0, 0.375, 0), denim_color)
	_create_box(_body_bob_node, Vector3(0.32, 0.18, 0.05), Vector3(0, 0.60, -0.21), denim_color)
	
	_create_box(_body_bob_node, Vector3(0.06, 0.22, 0.49), Vector3(-0.13, 0.74, 0), strap_color) 
	_create_box(_body_bob_node, Vector3(0.06, 0.22, 0.49), Vector3(0.13, 0.74, 0), strap_color)  
	
	# 3. Head Node & Straw Hat
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.05, 0)
	_body_bob_node.add_child(_head_node)
	
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color)
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), nose_color)
	
	_create_box(_head_node, Vector3(0.65, 0.03, 0.65), Vector3(0, 0.36, 0), straw_color) 
	_create_box(_head_node, Vector3(0.24, 0.10, 0.24), Vector3(0, 0.42, 0), straw_color) 
	
	# Blinking Eyes
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	
	# 4. Linen Folded Arms
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.65, -0.23)
	_body_bob_node.add_child(_arms_node)
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), shirt_color)
	
	# 5. Sheathed Wood/Iron Hoe on Back (Diagonally mounted)
	var hoe_joint := Node3D.new()
	hoe_joint.name = "HarvestHoeJoint"
	hoe_joint.position = Vector3(0.1, 0.5, 0.24)
	hoe_joint.rotation = Vector3(0, 0, deg_to_rad(45)) 
	_body_bob_node.add_child(hoe_joint)
	
	_create_box(hoe_joint, Vector3(0.04, 0.52, 0.04), Vector3(0, 0, 0), strap_color) 
	_create_box(hoe_joint, Vector3(0.06, 0.06, 0.14), Vector3(0, 0.24, -0.06), iron_color) 
	_create_box(hoe_joint, Vector3(0.10, 0.18, 0.04), Vector3(0, 0.21, -0.12), iron_color) 

func _get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.5, 0.575)

func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.75, 0)

func _setup_floating_bubble() -> void:
	var sb_script: Script = load("res://src/Infrastructure/UI/SpeechBubble.gd")
	if sb_script != null:
		var bubble = sb_script.new() as Node3D
		add_child(bubble)
		bubble.call("set_text", "FARMER")

func interact(player_node: CharacterBody3D) -> void:
	var hud = player_node.get("hud")
	if is_instance_valid(hud):
		var intro_node: Resource = DialogueService.get_dialogue_node("farmer_intro")
		if intro_node == null:
			var fallback_node := DialogueNode.new()
			fallback_node.node_id = "farmer_intro"
			fallback_node.text = "Hello! I am tending these crops to keep the market well stocked. The soil of the Golden Bazaar is rich and bountiful!"
			DialogueService.register_node(fallback_node)
			intro_node = fallback_node
			
		hud.call("open_dialogue", intro_node, "Farmer")

func _physics_process(delta: float) -> void:
	if domain_entity.is_dead: 
		return
		
	# FASE A: Dynamic Agricultural AI scanning and pathfinding execution
	_process_farming_ai_intelligence(delta)
	
	super(delta)

## FASE A: Periodic Volumetric crop scanning and lock-on routine
func _process_farming_ai_intelligence(delta: float) -> void:
	var world_node := get_parent() as WorldController
	if not is_instance_valid(world_node):
		return
		
	var world_state := world_node.world_state
	if world_state == null:
		return
		
	if current_task != TaskState.EXAMINING:
		_scan_timer -= delta
		if _scan_timer <= 0.0:
			_scan_timer = 3.0 # Scan every 3 seconds
			_scan_for_ripe_crops(world_state)
	else:
		# If locked onto a crop, pathfind and harvest
		_execute_crop_harvesting(world_node, delta)

## Scans a 7x3x7 volume around the farmer to locate ripe golden wheat (Block ID 20)
func _scan_for_ripe_crops(world_state: WorldState) -> void:
	var my_coord := Vector3i(
		floori(global_position.x),
		floori(global_position.y),
		floori(global_position.z)
	)
	
	for x in range(-3, 4):
		for y in range(-1, 2):
			for z in range(-3, 4):
				var check_coord := my_coord + Vector3i(x, y, z)
				var block := world_state.get_block(check_coord)
				
				# BlockType.Type.CROP_RIPE is ID 20
				if block == BlockType.Type.CROP_RIPE:
					_target_crop_coord = check_coord
					_harvest_timer = 1.8 # Set 1.8 seconds of harvesting labor
					current_task = TaskState.EXAMINING
					print("[FarmerAI] Locked onto ripe wheat at: ", _target_crop_coord)
					return

## Controls walking towards the crop, executing arm swing, and replanting fresh seeds
func _execute_crop_harvesting(world_node: WorldController, delta: float) -> void:
	if _target_crop_coord.y == -999:
		current_task = TaskState.IDLE
		return
		
	# Calculate horizontal direction to target block
	var target_pos := Vector3(_target_crop_coord) + Vector3(0.5, 0.0, 0.5)
	var diff := target_pos - global_position
	diff.y = 0.0
	
	if diff.length() > 1.1:
		# Walk towards the crop
		_wander_direction = diff.normalized()
		velocity.x = _wander_direction.x * BASE_SPEED
		velocity.z = _wander_direction.z * BASE_SPEED
	else:
		# Reached! Stop walking, face the crop, and execute the labor timer
		velocity.x = 0.0
		velocity.z = 0.0
		_wander_direction = diff.normalized()
		
		_harvest_timer -= delta
		if _harvest_timer <= 0.0:
			# STRICT TYPING: Direct method call on the statically typed WorldController
			# 1. Harvest: Remove Ripe Wheat (Vanish old block)
			world_node.set_block_globally(_target_crop_coord, BlockType.Type.AIR)
			
			# 2. Replant: Place fresh Seed (ID 18) in its place (Perpetual farming!)
			world_node.set_block_globally(_target_crop_coord, BlockType.Type.CROP_SEED)
			print("[FarmerAI] Harvested and replanted seed at: ", _target_crop_coord)
			
			# 3. Hop physically in the air with farming joy!
			velocity.y = JUMP_VELOCITY
			
			# 4. Release lock-on
			_target_crop_coord = Vector3i(0, -999, 0)
			current_task = TaskState.IDLE
			_task_timer = 2.0

func _select_next_random_task() -> void:
	var roll := randf()
	if roll < 0.75:
		current_task = TaskState.EXAMINING 
		var angle := randf() * TAU
		_wander_direction = Vector3(cos(angle), 0, sin(angle))
		_task_timer = randf_range(3.0, 7.0)
	elif roll < 0.90:
		current_task = TaskState.WANDERING 
		var angle := randf() * TAU
		_wander_direction = Vector3(cos(angle), 0, sin(angle))
		_task_timer = randf_range(2.0, 4.0)
	else:
		current_task = TaskState.IDLE 
		_task_timer = randf_range(1.0, 2.5)

func _can_socialize() -> bool:
	# Socializing is disabled if the farmer is currently locked onto crop harvesting tasks
	return current_task != TaskState.EXAMINING
