# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: FarmerAIBehavior
# Description: Concrete AI behavior strategy implementing agricultural routines 
#              including local crop scanning, path navigation, and harvesting.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the agricultural 
#   decision-making state machine, completely isolated from physics and visuals.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. New crops or farming 
#   actions can be extended here without modifying standard entity nodes.
# - Liskov Substitution Principle (LSP): Adheres fully to the base contract, 
#   making it interchangeable with other behavior strategies.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name FarmerAIBehavior
extends IAIBehavior

const SCAN_INTERVAL_SEC: float = 3.0
const HARVEST_DURATION_SEC: float = 1.8

# Decoupled metadata keys to store state variables safely on the host node
const META_SCAN_TIMER := "farmer_scan_timer"
const META_TARGET_CROP := "farmer_target_crop"
const META_HARVEST_TIMER := "farmer_harvest_timer"


## Concrete Implementation: Drives the farmer's agricultural state machine
func evaluate_and_execute(host: CharacterBody3D, ai_component: Node, delta: float) -> void:
	var ai := ai_component as NPCAIComponent
	if ai == null or not is_instance_valid(host):
		return
		
	# Skip routines if the farmer is currently in dialog with the player
	if host.get("is_talking") == true:
		_reset_farmer_state(host, ai)
		return
		
	# Get or initialize state parameters on the host metadata container
	_initialize_metadata_if_missing(host)
	
	var scan_timer: float = host.get_meta(META_SCAN_TIMER)
	var target_crop: Vector3i = host.get_meta(META_TARGET_CROP)
	var harvest_timer: float = host.get_meta(META_HARVEST_TIMER)
	
	if ai.current_task != NPCAIComponent.TaskState.WORKING:
		# 1. SCANNING STATE: Look for mature wheat blocks nearby
		scan_timer -= delta
		if scan_timer <= 0.0:
			scan_timer = SCAN_INTERVAL_SEC
			var found_crop := _scan_for_ripe_crops(host)
			if found_crop != Vector3i(0, -999, 0):
				target_crop = found_crop
				harvest_timer = HARVEST_DURATION_SEC
				ai.current_task = NPCAIComponent.TaskState.WORKING
				
		host.set_meta(META_SCAN_TIMER, scan_timer)
		host.set_meta(META_TARGET_CROP, target_crop)
		host.set_meta(META_HARVEST_TIMER, harvest_timer)
	else:
		# 2. EXECUTION STATE: Move to target, play animations, and harvest
		_execute_crop_harvesting(host, ai, delta)


func _initialize_metadata_if_missing(host: CharacterBody3D) -> void:
	if not host.has_meta(META_SCAN_TIMER):
		host.set_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC)
	if not host.has_meta(META_TARGET_CROP):
		host.set_meta(META_TARGET_CROP, Vector3i(0, -999, 0))
	if not host.has_meta(META_HARVEST_TIMER):
		host.set_meta(META_HARVEST_TIMER, 0.0)


func _reset_farmer_state(host: CharacterBody3D, ai: NPCAIComponent) -> void:
	ai.current_task = NPCAIComponent.TaskState.IDLE
	ai.wander_direction = Vector3.ZERO
	host.set_meta(META_TARGET_CROP, Vector3i(0, -999, 0))
	host.set_meta(META_HARVEST_TIMER, 0.0)


## Proximity Scanner: Identifies mature wheat blocks within 3 meters
func _scan_for_ripe_crops(host: CharacterBody3D) -> Vector3i:
	var world_node := host.get_parent()
	if world_node == null or not "world_state" in world_node:
		return Vector3i(0, -999, 0)
		
	var ws: WorldState = world_node.world_state
	if ws == null:
		return Vector3i(0, -999, 0)
		
	var my_coord := Vector3i(floori(host.global_position.x), floori(host.global_position.y), floori(host.global_position.z))
	
	for x in range(-3, 4):
		for y in range(-1, 2):
			for z in range(-3, 4):
				var check_coord := my_coord + Vector3i(x, y, z)
				if ws.get_block(check_coord) == BlockType.Type.CROP_RIPE:
					return check_coord
					
	return Vector3i(0, -999, 0)


## Direct Path Routing: Moves to coordinates and triggers visual swing strikes
func _execute_crop_harvesting(host: CharacterBody3D, ai: NPCAIComponent, delta: float) -> void:
	var target_crop: Vector3i = host.get_meta(META_TARGET_CROP)
	if target_crop.y == -999:
		ai.current_task = NPCAIComponent.TaskState.IDLE
		return
		
	var target_pos := Vector3(target_crop) + Vector3(0.5, 0.0, 0.5)
	var diff := target_pos - host.global_position
	diff.y = 0.0
	
	var base_speed: float = 1.3
	if "BASE_SPEED" in host:
		base_speed = host.get("BASE_SPEED")
		
	if diff.length() > 1.1:
		# Chase Target: Translate physical position
		var wander_dir := diff.normalized()
		host.velocity.x = wander_dir.x * base_speed
		host.velocity.z = wander_dir.z * base_speed
		ai.wander_direction = wander_dir
		
		# Jump over short visual obstructions
		if host.is_on_wall() and host.is_on_floor():
			var jump_vel: float = 5.0
			if "JUMP_VELOCITY" in host:
				jump_vel = host.get("JUMP_VELOCITY")
			host.velocity.y = jump_vel
	else:
		# Target Reached: Halt coordinates and execute swing timers
		host.velocity.x = 0.0
		host.velocity.z = 0.0
		ai.wander_direction = diff.normalized()
		
		var vis_rep: IEntityVisualRepresentation = host.get("visual_representation") as IEntityVisualRepresentation
		if vis_rep != null:
			vis_rep.trigger_attack_visuals()
			
		var harvest_timer: float = host.get_meta(META_HARVEST_TIMER)
		harvest_timer -= delta
		
		if harvest_timer <= 0.0:
			# Execute Block-Overwrites across the coordinate system
			var world_node := host.get_parent()
			if is_instance_valid(world_node) and world_node.has_method("set_block_globally"):
				world_node.call("set_block_globally", target_crop, BlockType.Type.AIR)
				world_node.call("set_block_globally", target_crop, BlockType.Type.CROP_SEED)
				
				_spawn_replant_particles_synchronous(world_node, Vector3(target_crop))
				
			host.velocity.y = 5.0 # Hop with joy
			target_crop = Vector3i(0, -999, 0)
			ai.current_task = NPCAIComponent.TaskState.IDLE
			ai.task_timer = 2.0 
			
		host.set_meta(META_TARGET_CROP, target_crop)
		host.set_meta(META_HARVEST_TIMER, harvest_timer)


## Sows crop visual particle feedback over target soils
func _spawn_replant_particles_synchronous(world_node: Node, pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 8
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.lifetime = 0.4
	
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.2, 0.1, 0.2)
	pm.direction = Vector3(0, 1.0, 0)
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 2.5
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	particles.process_material = pm
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var mat := ORMMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.85, 0.25) # Fertile green
	mesh.material = mat
	particles.draw_pass_1 = mesh
	
	world_node.add_child(particles)
	particles.global_position = pos + Vector3(0.5, 0.25, 0.5)
	particles.emitting = true
	
	world_node.get_tree().create_timer(0.65).timeout.connect(particles.queue_free)


func sprintf(format_str: String, val: float) -> String:
	return format_str % val
