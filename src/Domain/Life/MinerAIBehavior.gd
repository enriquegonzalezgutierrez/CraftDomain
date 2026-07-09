# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: MinerAIBehavior
# Description: Specialized AI behavior strategy implementing deep cavern mining
#              routines for the Cave Miner NPC. It scans surrounding blocks 
#              seeking Coal Ore veins, navigating to them, executing pickaxe 
#              strikes, and procedurally replacing the mined blocks with raw Stone,
#              triggering geological particle feedback.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the mineral scanning, 
#   navigation pathing, and extraction loop of the Miner entity.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. New ores, diamond 
#   drills, or cave-in evasion parameters can be appended cleanly here.
# - Liskov Substitution Principle (LSP): Fully compatible with the IAIBehavior 
#   contract signatures, making it interchangeable with other strategies.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/MinerAIBehavior.gd
# ==============================================================================
class_name MinerAIBehavior
extends IAIBehavior

const SCAN_INTERVAL_SEC: float = 3.0
const MINE_DURATION_SEC: float = 2.0

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_SCAN_TIMER := "miner_scan_timer"
const META_TARGET_ORE := "miner_target_ore"
const META_MINE_TIMER := "miner_mine_timer"


## Concrete Contract: Drives the cavern mining and exploration cycles
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	# Skip routines if currently chatting with the player
	if host.get("is_talking") == true:
		_reset_miner_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	
	var scan_timer: float = host.get_meta(META_SCAN_TIMER) as float
	var target_ore: Vector3i = host.get_meta(META_TARGET_ORE) as Vector3i
	var mine_timer: float = host.get_meta(META_MINE_TIMER) as float
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var current_task: int = ai.get("current_task") as int
	
	if current_task != TASK_WORKING:
		# 1. CAVERN VEIN SCANNING STATE
		scan_timer -= delta
		if scan_timer <= 0.0:
			scan_timer = SCAN_INTERVAL_SEC
			var found_ore: Vector3i = _scan_for_coal_veins(host)
			if found_ore != Vector3i(0, -999, 0):
				target_ore = found_ore
				mine_timer = MINE_DURATION_SEC
				ai.set("current_task", TASK_WORKING)
				
		host.set_meta(META_SCAN_TIMER, scan_timer)
		host.set_meta(META_TARGET_ORE, target_ore)
		host.set_meta(META_MINE_TIMER, mine_timer)
	else:
		# 2. ORE EXTRACTION STATE
		_execute_cavern_mining(host, ai, delta)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_SCAN_TIMER):
		host.set_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC)
	if not host.has_meta(META_TARGET_ORE):
		host.set_meta(META_TARGET_ORE, Vector3i(0, -999, 0))
	if not host.has_meta(META_MINE_TIMER):
		host.set_meta(META_MINE_TIMER, 0.0)


func _reset_miner_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_TARGET_ORE, Vector3i(0, -999, 0))
	host.set_meta(META_MINE_TIMER, 0.0)


## Proximity Scanner: Identifies Coal Ore (ID 21) within 3 meters in the caverns
func _scan_for_coal_veins(host: Object) -> Vector3i:
	var world_node: Node = null
	if host.has_method("get_parent"):
		world_node = host.call("get_parent") as Node
		
	if world_node == null or not "world_state" in world_node:
		return Vector3i(0, -999, 0)
		
	var ws: WorldState = world_node.get("world_state") as WorldState
	if ws == null:
		return Vector3i(0, -999, 0)
		
	var host_pos: Vector3 = host.get("global_position")
	var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
	
	# Scans adjacent blocks in a 3D bounding box
	for x: int in range(-3, 4):
		for y: int in range(-1, 2):
			for z: int in range(-3, 4):
				var check_coord := my_coord + Vector3i(x, y, z)
				# Block ID 21 is COAL_ORE (matches BlockType.Type.COAL_ORE)
				if ws.get_block(check_coord) == 21:
					return check_coord
					
	return Vector3i(0, -999, 0)


## Mining Executor: Guides movement, triggers pickaxe swings, and replace ore with Stone
func _execute_cavern_mining(host: Object, ai: Object, delta: float) -> void:
	var target_ore: Vector3i = host.get_meta(META_TARGET_ORE) as Vector3i
	if target_ore.y == -999:
		ai.set("current_task", TASK_IDLE)
		return
		
	var target_pos := Vector3(target_ore) + Vector3(0.5, 0.0, 0.5)
	var host_pos: Vector3 = host.get("global_position")
	var diff := target_pos - host_pos
	diff.y = 0.0
	
	var base_speed: float = 1.3
	if "BASE_SPEED" in host:
		base_speed = host.get("BASE_SPEED") as float
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	
	if diff.length() > 1.3:
		# 1. Walk towards the coal vein
		var wander_dir := diff.normalized()
		velocity.x = wander_dir.x * base_speed
		velocity.z = wander_dir.z * base_speed
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
	else:
		# 2. Arrived: Halt translations, lock gaze and strike pickaxe!
		velocity.x = 0.0
		velocity.z = 0.0
		host.set("velocity", velocity)
		ai.set("wander_direction", diff.normalized())
		
		var vis_rep: Resource = host.get("visual_representation") as Resource
		if is_instance_valid(vis_rep) and vis_rep.has_method("trigger_attack_visuals"):
			vis_rep.call("trigger_attack_visuals") # Animates pickaxe swing!
			
		var mine_timer: float = host.get_meta(META_MINE_TIMER) as float
		mine_timer -= delta
		
		if mine_timer <= 0.0:
			# Vein Depleted! Convert globally from COAL_ORE (21) to STONE (1)
			var world_node: Node = null
			if host.has_method("get_parent"):
				world_node = host.call("get_parent") as Node
				
			if is_instance_valid(world_node) and world_node.has_method("set_block_globally"):
				# Block IDs: 1 = STONE
				world_node.call("set_block_globally", target_ore, 1)
				
				# Play rock breaking sound and spawn debris particles
				AudioService.play_sfx_static("block_break", Vector3(target_ore))
				
			# Jump with joy!
			velocity.y = 5.0 
			host.set("velocity", velocity)
			
			target_ore = Vector3i(0, -999, 0)
			ai.set("current_task", TASK_IDLE)
			ai.set("task_timer", 3.0) # Rest time before next sweep
			
		host.set_meta(META_MINE_TIMER, mine_timer)
		host.set_meta(META_TARGET_ORE, target_ore)
