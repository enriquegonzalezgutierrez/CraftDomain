# ==============================================================================
# Project: CraftDomain
# Description: Farmer NPC entity. Inherits from the abstract base class PassiveEntity.
#              AI UPGRADE: Swapped EXAMINING for WORKING state to ensure the 
#              base class does not overwrite the Farmer's pathfinding velocity.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name FarmerEntity
extends PassiveEntity

var _scan_timer: float = 3.0
var _target_crop_coord := Vector3i(0, -999, 0)
var _harvest_timer: float = 0.0

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1)
	name = "Entity_FARMER"

func _build_visual_representation() -> void:
	var shirt_color := Color(0.85, 0.82, 0.75)       
	var denim_color := Color(0.20, 0.35, 0.55)       
	var strap_color := Color(0.35, 0.22, 0.15)       
	var skin_color := Color(0.95, 0.75, 0.65)        
	var nose_color := Color(0.85, 0.65, 0.55)        
	var straw_color := Color(0.88, 0.78, 0.42)       
	var boots_color := Color(0.18, 0.14, 0.11)       
	var iron_color := Color(0.50, 0.50, 0.52)        
	
	_create_box(_body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), boots_color)
	_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), shirt_color)
	_create_box(_body_bob_node, Vector3(0.47, 0.45, 0.47), Vector3(0, 0.375, 0), denim_color)
	_create_box(_body_bob_node, Vector3(0.32, 0.18, 0.05), Vector3(0, 0.60, -0.21), denim_color)
	_create_box(_body_bob_node, Vector3(0.06, 0.22, 0.49), Vector3(-0.13, 0.74, 0), strap_color) 
	_create_box(_body_bob_node, Vector3(0.06, 0.22, 0.49), Vector3(0.13, 0.74, 0), strap_color)  
	
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.05, 0)
	_body_bob_node.add_child(_head_node)
	
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color)
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), nose_color)
	_create_box(_head_node, Vector3(0.65, 0.03, 0.65), Vector3(0, 0.36, 0), straw_color) 
	_create_box(_head_node, Vector3(0.24, 0.10, 0.24), Vector3(0, 0.42, 0), straw_color) 
	
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.65, -0.23)
	_body_bob_node.add_child(_arms_node)
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), shirt_color)
	
	var hoe_joint := Node3D.new()
	hoe_joint.name = "HarvestHoeJoint"
	hoe_joint.position = Vector3(0.1, 0.5, 0.24)
	hoe_joint.rotation = Vector3(0, 0, deg_to_rad(45)) 
	_body_bob_node.add_child(hoe_joint)
	
	_create_box(hoe_joint, Vector3(0.04, 0.52, 0.04), Vector3(0, 0, 0), strap_color) 
	_create_box(hoe_joint, Vector3(0.06, 0.06, 0.14), Vector3(0, 0.24, -0.06), iron_color) 
	_create_box(hoe_joint, Vector3(0.10, 0.18, 0.04), Vector3(0, 0.21, -0.12), iron_color) 

func _get_collision_box_size() -> Vector3: return Vector3(0.575, 1.5, 0.575)
func _get_collision_box_position() -> Vector3: return Vector3(0, 0.75, 0)

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
	_process_farming_ai_intelligence(delta)
	super(delta)

func _process_farming_ai_intelligence(delta: float) -> void:
	var world_node := get_parent() as WorldController
	if not is_instance_valid(world_node) or world_node.world_state == null: return
		
	# FIX: Using the new WORKING state so the pathfinding speed is not restricted by PassiveEntity
	if current_task != TaskState.WORKING:
		_scan_timer -= delta
		if _scan_timer <= 0.0:
			_scan_timer = 3.0
			_scan_for_ripe_crops(world_node.world_state)
	else:
		_execute_crop_harvesting(world_node, delta)

func _scan_for_ripe_crops(world_state: WorldState) -> void:
	var my_coord := Vector3i(floori(global_position.x), floori(global_position.y), floori(global_position.z))
	for x in range(-3, 4):
		for y in range(-1, 2):
			for z in range(-3, 4):
				var check_coord := my_coord + Vector3i(x, y, z)
				if world_state.get_block(check_coord) == BlockType.Type.CROP_RIPE:
					_target_crop_coord = check_coord
					_harvest_timer = 1.8 
					current_task = TaskState.WORKING # New priority state
					print("[FarmerAI] Locked onto ripe wheat at: ", _target_crop_coord)
					return

func _execute_crop_harvesting(world_node: WorldController, delta: float) -> void:
	if _target_crop_coord.y == -999:
		current_task = TaskState.IDLE
		return
		
	var target_pos := Vector3(_target_crop_coord) + Vector3(0.5, 0.0, 0.5)
	var diff := target_pos - global_position
	diff.y = 0.0
	
	if diff.length() > 1.1:
		_wander_direction = diff.normalized()
		velocity.x = _wander_direction.x * BASE_SPEED
		velocity.z = _wander_direction.z * BASE_SPEED
		
		# AI Smart Wall Jump for Farmer
		if is_on_wall() and is_on_floor():
			velocity.y = JUMP_VELOCITY
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_wander_direction = diff.normalized()
		
		_harvest_timer -= delta
		if _harvest_timer <= 0.0:
			world_node.set_block_globally(_target_crop_coord, BlockType.Type.AIR)
			world_node.set_block_globally(_target_crop_coord, BlockType.Type.CROP_SEED)
			print("[FarmerAI] Harvested and replanted seed at: ", _target_crop_coord)
			
			velocity.y = JUMP_VELOCITY
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
	return current_task != TaskState.WORKING
