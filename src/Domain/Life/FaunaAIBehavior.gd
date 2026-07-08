# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: FaunaAIBehavior
# Description: Concrete AI behavior strategy implementing standard wildlife routines,
#              including peaceful grazing, threat avoidance, and panic-flight with logs.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates grazing and 
#   evasion decision trees, isolating animal instincts from physical entity nodes.
# - Open-Closed Principle (OCP): Extends IAIBehavior. Species-specific parameters 
#   (such as crawling speed dampening or flight heights) are managed dynamically.
# - Liskov Substitution Principle (LSP): Fully interchangeable with all behaviors, 
#   operating seamlessly on any valid wildlife character host.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name FaunaAIBehavior
extends IAIBehavior

const SPEED_PANIC: float = 2.5
const SPEED_GRAZE: float = 0.8

const SENSORY_RANGE_SQ: float = 64.0 # 8.0 meters squared threat detection

const META_WANDER_TIMER := "fauna_wander_timer"
const META_WANDER_DIR := "fauna_wander_dir"
const META_PANIC_TIMER := "fauna_panic_timer"
const META_STUCK_TIMER := "fauna_stuck_timer"


func _init() -> void:
	# ==========================================================================
	# OCP FORCEFIELD OVERRIDE
	# Wildlife completely intercepts movement, bypassing civilian schedules
	# ==========================================================================
	overrides_wandering = true


## Concrete Implementation: Controls wildlife grazing and high-frequency panic paths
func evaluate_and_execute(host: CharacterBody3D, ai_component: Node, delta: float) -> void:
	var ai := ai_component as NPCAIComponent
	if ai == null or not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER)
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR)
	var panic_timer: float = host.get_meta(META_PANIC_TIMER)
	var stuck_timer: float = host.get_meta(META_STUCK_TIMER)
	
	# Determine if host is currently panicking due to receiving damage
	var is_panicking := false
	if panic_timer > 0.0:
		panic_timer -= delta
		host.set_meta(META_PANIC_TIMER, panic_timer)
		is_panicking = true
		
	# 1. SCAN FOR PROXIMITY THREATS (Zombies)
	if not is_panicking:
		var closest_threat := _scan_for_hostile_monsters(host)
		if closest_threat != null:
			# Sense threat: Trigger panic escape instantly
			panic_timer = 4.5
			var escape_dir := (host.global_position - closest_threat.global_position).normalized()
			escape_dir.y = 0.0
			wander_dir = escape_dir
			is_panicking = true
			
			host.set_meta(META_PANIC_TIMER, panic_timer)
			host.set_meta(META_WANDER_DIR, wander_dir)
			print("[AI DEBUG] [", host.name, "] SENSORY SHIELD: Spied close-range hostile monster: ", closest_threat.name, "! Scurrying away in panic!")
			
	# 2. RUN PANIC ACTION FLIGHT
	if is_panicking:
		ai.current_task = NPCAIComponent.TaskState.PANIC
		
		# Change escape headings frequently to look frantic
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = randf_range(0.3, 0.8)
			var angle := randf() * TAU
			var random_panic_dir := Vector3(cos(angle), 0.0, sin(angle))
			
			if _is_direction_safe_fauna(host, random_panic_dir):
				wander_dir = random_panic_dir
				
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)
		
		print("[AI DEBUG] [", host.name, "] Scurrying frantically! Time remaining in panic: ", sprintf("%.1f", panic_timer), "s")
		
		# Jump over block obstacles frantically
		if host.is_on_wall() and host.is_on_floor():
			host.velocity.y = 5.0
			
	# 3. RUN COZY GRAZING / ROAMING ACTION
	else:
		ai.current_task = NPCAIComponent.TaskState.WANDERING
		
		wander_timer -= delta
		if wander_timer <= 0.0:
			var roll := randf()
			if roll < 0.45:
				# Walk and graze
				var angle := randf() * TAU
				var target_dir := Vector3(cos(angle), 0.0, sin(angle))
				
				if _is_direction_safe_fauna(host, target_dir):
					wander_dir = target_dir
					print("[AI DEBUG] [", host.name, "] Grazing action: walking slowly to heading vector: ", wander_dir)
				else:
					wander_dir = Vector3.ZERO
				wander_timer = randf_range(2.0, 5.0)
			else:
				# Rest in place
				wander_dir = Vector3.ZERO
				wander_timer = randf_range(1.5, 4.0)
				print("[AI DEBUG] [", host.name, "] Grazing action: Sniffing the grass in place.")
				
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)
		
		# Climb stairs/blocks slowly
		if wander_dir != Vector3.ZERO and host.is_on_wall():
			if host.is_on_floor():
				host.velocity.y = 5.0
				
			stuck_timer += delta
			if stuck_timer > 0.4:
				stuck_timer = 0.0
				var wall_normal := host.get_wall_normal()
				var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
				if flat_normal != Vector3.ZERO:
					wander_dir = wander_dir.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.3, 0.3)).normalized()
					host.set_meta(META_WANDER_DIR, wander_dir)
					print("[AI DEBUG] [", host.name, "] Path collided, calculated bounce graze trajectory: ", wander_dir)
			host.set_meta(META_STUCK_TIMER, stuck_timer)
		else:
			stuck_timer = 0.0
			host.set_meta(META_STUCK_TIMER, stuck_timer)

	# 4. DISPATCH VELOCITIES AND GAZE ROTATIONS
	if wander_dir != Vector3.ZERO:
		var speed_coef := SPEED_PANIC if is_panicking else SPEED_GRAZE
		
		# Apply a crawl dampening modifier if the host is a slow sea turtle on sand
		if host.name.contains("TURTLE") and host.is_on_floor():
			speed_coef *= 0.5
			
		host.velocity.x = wander_dir.x * speed_coef
		host.velocity.z = wander_dir.z * speed_coef
		ai.wander_direction = wander_dir
		
		# Turn physical mesh towards walking headings
		var visuals_node := host.get_node_or_null("NPCVisualComponent/Visuals") as Node3D
		if is_instance_valid(visuals_node):
			var target_look := host.global_position + wander_dir
			if not host.global_position.is_equal_approx(target_look):
				var current_rot_x := visuals_node.rotation.x
				var current_rot_z := visuals_node.rotation.z
				visuals_node.look_at(target_look, Vector3.UP)
				# ==============================================================
				# ROLE-BASED ORIENTATION BYPASS (OCP SHIELD)
				# Animals already face -Z naturally. They skip rotate_y(PI).
				# ==============================================================
				visuals_node.rotation.x = current_rot_x
				visuals_node.rotation.z = current_rot_z
	else:
		host.velocity.x = move_toward(host.velocity.x, 0.0, SPEED_GRAZE)
		host.velocity.z = move_toward(host.velocity.z, 0.0, SPEED_GRAZE)
		ai.wander_direction = Vector3.ZERO


func _initialize_metadata_if_missing(host: CharacterBody3D) -> void:
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_PANIC_TIMER):
		host.set_meta(META_PANIC_TIMER, 0.0)
	if not host.has_meta(META_STUCK_TIMER):
		host.set_meta(META_STUCK_TIMER, 0.0)


## Proximity Scanner: Uses group listings to locate nearest hostiles
func _scan_for_hostile_monsters(host: CharacterBody3D) -> Node3D:
	if not host.is_inside_tree():
		return null
		
	var closest_threat: Node3D = null
	var min_dist_sq := SENSORY_RANGE_SQ
	
	var hostiles := host.get_tree().get_nodes_in_group("hostiles")
	for child: Node in hostiles:
		if is_instance_valid(child):
			var zombie_domain := child.get("domain_entity") as VoxelEntity
			if zombie_domain != null and not zombie_domain.is_dead:
				var dist_sq := host.global_position.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_threat = child as Node3D
					
	return closest_threat


## Look-Ahead Validator: Ensures terrestrial wildlife doesn't drown and aquatic stays constrained
func _is_direction_safe_fauna(host: CharacterBody3D, dir: Vector3) -> bool:
	var world_node := host.get_parent()
	if not is_instance_valid(world_node) or not "world_state" in world_node:
		return true
		
	var ws: WorldState = world_node.world_state
	if ws == null:
		return true
		
	var check_pos := host.global_position + dir * 1.5
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	var block_below := ws.get_block(block_below_coord)
	var block_at := ws.get_block(block_at_coord)
	
	var habitat: int = 0
	if host.has_method("_get_habitat"):
		habitat = host.call("_get_habitat") as int
		
	if habitat == 2: # AQUATIC
		return block_below == BlockType.Type.WATER or block_at == BlockType.Type.WATER
	elif habitat == 1: # AMPHIBIOUS
		var is_water := block_below == BlockType.Type.WATER or block_at == BlockType.Type.WATER
		var is_shore := block_below == BlockType.Type.SAND or block_below == BlockType.Type.MUD
		return is_water or is_shore
	else: # TERRESTRIAL
		var is_water := block_below == BlockType.Type.WATER or block_below == BlockType.Type.LAVA or block_at == BlockType.Type.WATER
		var is_void := block_below == BlockType.Type.AIR
		
		if is_void:
			var block_2_below := ws.get_block(block_below_coord + Vector3i(0, -1, 0))
			if block_2_below != BlockType.Type.AIR and block_2_below != BlockType.Type.WATER and block_2_below != BlockType.Type.LAVA:
				is_void = false
				
		return not is_water and not is_void


func sprintf(format_str: String, val: float) -> String:
	return format_str % val
