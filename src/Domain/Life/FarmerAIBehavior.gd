# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: FarmerAIBehavior
# Description: Concrete AI behavior strategy implementing agricultural routines 
#              including local crop scanning, path navigation, and harvesting.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the agricultural 
#   decision-making state machine, completely isolated from physics and visuals.
#   All raw physical wall-climbing and jump physics are delegated to Infrastructure.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. New crops or farming 
#   actions can be extended here without modifying standard entity nodes.
# - Liskov Substitution Principle (LSP): Adheres fully to the base contract, 
#   making it interchangeable with other behavior strategies.
# - Dependency Inversion Principle (DIP): Communicates with the physical actor 
#   and AI systems using generic 'Object' dynamic routing, eliminating concrete 
#   compile-time imports of 'NPCAIComponent' or framework 'CharacterBody3D' nodes.
# ==============================================================================
class_name FarmerAIBehavior
extends IAIBehavior

const SCAN_INTERVAL_SEC: float = 3.0
const HARVEST_DURATION_SEC: float = 1.8

# Decoupled state mirrors to prevent importing Infrastructure enums directly
const TASK_IDLE = 0
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_SCAN_TIMER := "farmer_scan_timer"
const META_TARGET_CROP := "farmer_target_crop"
const META_HARVEST_TIMER := "farmer_harvest_timer"


## Concrete Implementation: Drives the farmer's agricultural state machine
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	# Skip routines if the farmer is currently in dialog with the player
	if host.get("is_talking") == true:
		_reset_farmer_state(host)
		return
		
	# Get or initialize state parameters on the host metadata container
	_initialize_metadata_if_missing(host)
	
	var scan_timer: float = host.get_meta(META_SCAN_TIMER)
	var target_crop: Vector3i = host.get_meta(META_TARGET_CROP)
	var harvest_timer: float = host.get_meta(META_HARVEST_TIMER)
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var current_task: int = ai.get("current_task")
	
	if current_task != TASK_WORKING:
		# 1. SCANNING STATE: Look for mature wheat blocks nearby
		scan_timer -= delta
		if scan_timer <= 0.0:
			scan_timer = SCAN_INTERVAL_SEC
			var found_crop := _scan_for_ripe_crops(host)
			if found_crop != Vector3i(0, -999, 0):
				target_crop = found_crop
				harvest_timer = HARVEST_DURATION_SEC
				ai.set("current_task", TASK_WORKING)
				
		host.set_meta(META_SCAN_TIMER, scan_timer)
		host.set_meta(META_TARGET_CROP, target_crop)
		host.set_meta(META_HARVEST_TIMER, harvest_timer)
	else:
		# 2. EXECUTION STATE: Move to target, play animations, and harvest
		_execute_crop_harvesting(host, ai, delta)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_SCAN_TIMER):
		host.set_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC)
	if not host.has_meta(META_TARGET_CROP):
		host.set_meta(META_TARGET_CROP, Vector3i(0, -999, 0))
	if not host.has_meta(META_HARVEST_TIMER):
		host.set_meta(META_HARVEST_TIMER, 0.0)


func _reset_farmer_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_TARGET_CROP, Vector3i(0, -999, 0))
	host.set_meta(META_HARVEST_TIMER, 0.0)


## Proximity Scanner: Identifies mature wheat blocks within 3 meters
func _scan_for_ripe_crops(host: Object) -> Vector3i:
	var world_node: Node = null
	if host.has_method("get_parent"):
		world_node = host.call("get_parent") as Node
		
	if world_node == null or not "world_state" in world_node:
		return Vector3i(0, -999, 0)
		
	var ws: WorldState = world_node.world_state
	if ws == null:
		return Vector3i(0, -999, 0)
		
	var host_pos: Vector3 = host.get("global_position")
	var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
	
	for x in range(-3, 4):
		for y in range(-1, 2):
			for z in range(-3, 4):
				var check_coord := my_coord + Vector3i(x, y, z)
				# 20 corresponds to BlockType.Type.CROP_RIPE
				if ws.get_block(check_coord) == 20:
					return check_coord
					
	return Vector3i(0, -999, 0)


## Direct Path Routing: Moves to coordinates and triggers visual swing strikes
func _execute_crop_harvesting(host: Object, ai: Object, delta: float) -> void:
	var target_crop: Vector3i = host.get_meta(META_TARGET_CROP)
	if target_crop.y == -999:
		ai.set("current_task", TASK_IDLE)
		return
		
	var target_pos := Vector3(target_crop) + Vector3(0.5, 0.0, 0.5)
	var host_pos: Vector3 = host.get("global_position")
	var diff := target_pos - host_pos
	diff.y = 0.0
	
	var base_speed: float = 1.3
	if "BASE_SPEED" in host:
		base_speed = host.get("BASE_SPEED")
		
	# Declare velocity once at scope level to avoid local shadowing warnings
	var velocity: Vector3 = host.get("velocity")
		
	if diff.length() > 1.1:
		# Chase Target: Translate physical position
		var wander_dir := diff.normalized()
		velocity.x = wander_dir.x * base_speed
		velocity.z = wander_dir.z * base_speed
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
		
		# NOTE: Wall physical step-climbing is handled centraly by NPCAIComponent.gd
	else:
		# Target Reached: Halt coordinates and execute swing timers
		velocity.x = 0.0
		velocity.z = 0.0
		host.set("velocity", velocity)
		ai.set("wander_direction", diff.normalized())
		
		var vis_rep: Resource = host.get("visual_representation")
		if is_instance_valid(vis_rep) and vis_rep.has_method("trigger_attack_visuals"):
			vis_rep.call("trigger_attack_visuals")
			
		var harvest_timer: float = host.get_meta(META_HARVEST_TIMER)
		harvest_timer -= delta
		
		if harvest_timer <= 0.0:
			# Execute Block-Overwrites across the coordinate system
			var world_node: Node = null
			if host.has_method("get_parent"):
				world_node = host.call("get_parent") as Node
				
			if is_instance_valid(world_node) and world_node.has_method("set_block_globally"):
				# 0 = BlockType.Type.AIR, 18 = BlockType.Type.CROP_SEED
				world_node.call("set_block_globally", target_crop, 0)
				world_node.call("set_block_globally", target_crop, 18)
				
				# DDD COMPLIANT: Ask the infrastructure controller to trigger the visual particles
				if world_node.has_method("spawn_replant_particles"):
					world_node.call("spawn_replant_particles", Vector3(target_crop))
				
			velocity.y = 5.0 # Hop with joy
			host.set("velocity", velocity)
			
			target_crop = Vector3i(0, -999, 0)
			ai.set("current_task", TASK_IDLE)
			ai.set("task_timer", 2.0)
			
		host.set_meta(META_TARGET_CROP, target_crop)
		host.set_meta(META_HARVEST_TIMER, harvest_timer)
