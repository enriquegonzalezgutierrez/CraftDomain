# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: FaunaAIBehavior
# Description: Generic AI behavior strategy implementing standard wilderness 
#              wildlife routines (grazing, peaceful roaming, and active threat 
#              evasion/panic flight). Fully decoupled from specific species.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates standard 
#   animal grazing patterns and panic paths.
# - Open-Closed Principle (OCP): COMPLETELY DECOUPLED. All hardcoded string checks
#   (like matching the word "TURTLE") have been purged, allowing the class to 
#   remain strictly closed to modifications when adding new animal species.
# - Liskov Substitution Principle (LSP): Serves as a reliable, uniform contract.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/FaunaAIBehavior.gd
# ==============================================================================
class_name FaunaAIBehavior
extends IAIBehavior

const SPEED_PANIC: float = 2.5
const SPEED_GRAZE: float = 0.8

const SENSORY_RANGE_SQ: float = 64.0 # 8.0 meters squared threat detection

# Decoupled state mirrors to prevent importing Infrastructure enums directly
const TASK_WANDERING = 1
const TASK_PANIC = 5

const META_WANDER_TIMER := "fauna_wander_timer"
const META_WANDER_DIR := "fauna_wander_dir"
const META_PANIC_TIMER := "fauna_panic_timer"
const META_STUCK_TIMER := "fauna_stuck_timer"


func _init() -> void:
	# Wildlife completely intercepts movement, bypassing civilian schedules
	overrides_wandering = true


## Concrete Implementation: Controls wildlife grazing and high-frequency panic paths
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var panic_timer: float = host.get_meta(META_PANIC_TIMER) as float
	var stuck_timer: float = host.get_meta(META_STUCK_TIMER) as float
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	# Unify physical velocity reading at top level
	var velocity: Vector3 = host.get("velocity")
	
	# Determine if host is currently panicking due to receiving damage
	var is_panicking := false
	if panic_timer > 0.0:
		panic_timer -= delta
		host.set_meta(META_PANIC_TIMER, panic_timer)
		is_panicking = true
		
	# 1. SCAN FOR PROXIMITY THREATS (Zombies)
	if not is_panicking:
		var closest_threat: Object = _scan_for_hostile_monsters(host)
		if closest_threat != null:
			# Sense threat: Trigger panic escape instantly
			panic_timer = 4.5
			var host_pos: Vector3 = host.get("global_position")
			var threat_pos: Vector3 = closest_threat.get("global_position")
			var escape_dir := (host_pos - threat_pos).normalized()
			escape_dir.y = 0.0
			wander_dir = escape_dir
			is_panicking = true
			
			host.set_meta(META_PANIC_TIMER, panic_timer)
			host.set_meta(META_WANDER_DIR, wander_dir)
			
	# 2. RUN PANIC ACTION FLIGHT
	if is_panicking:
		ai.set("current_task", TASK_PANIC)
		
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
			
	# 3. RUN COZY GRAZING / ROAMING ACTION
	else:
		ai.set("current_task", TASK_WANDERING)
		
		wander_timer -= delta
		if wander_timer <= 0.0:
			var roll := randf()
			if roll < 0.45:
				# Walk and graze
				var angle := randf() * TAU
				var target_dir := Vector3(cos(angle), 0.0, sin(angle))
				
				if _is_direction_safe_fauna(host, target_dir):
					wander_dir = target_dir
				else:
					wander_dir = Vector3.ZERO
				wander_timer = randf_range(2.0, 5.0)
			else:
				# Rest in place
				wander_dir = Vector3.ZERO
				wander_timer = randf_range(1.5, 4.0)
				
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)
		
		# Climb and collide re-direction checks
		if wander_dir != Vector3.ZERO and host.call("is_on_wall"):
			stuck_timer += delta
			if stuck_timer > 0.4:
				stuck_timer = 0.0
				var wall_normal: Vector3 = host.call("get_wall_normal")
				var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
				if flat_normal != Vector3.ZERO:
					wander_dir = wander_dir.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.3, 0.3)).normalized()
					host.set_meta(META_WANDER_DIR, wander_dir)
			host.set_meta(META_STUCK_TIMER, stuck_timer)
		else:
			stuck_timer = 0.0
			host.set_meta(META_STUCK_TIMER, stuck_timer)

	# 4. DISPATCH VELOCITIES
	if wander_dir != Vector3.ZERO:
		var speed_coef := SPEED_PANIC if is_panicking else SPEED_GRAZE
		
		velocity.x = wander_dir.x * speed_coef
		velocity.z = wander_dir.z * speed_coef
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_GRAZE)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_GRAZE)
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_PANIC_TIMER):
		host.set_meta(META_PANIC_TIMER, 0.0)
	if not host.has_meta(META_STUCK_TIMER):
		host.set_meta(META_STUCK_TIMER, 0.0)


## Proximity Scanner: Uses group listings to locate nearest hostiles
func _scan_for_hostile_monsters(host: Object) -> Object:
	var closest_threat: Object = null
	var min_dist_sq := SENSORY_RANGE_SQ
	
	var hostiles: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			hostiles = tree.call("get_nodes_in_group", "hostiles")
			
	var host_pos: Vector3 = host.get("global_position")
	for child: Object in hostiles:
		if is_instance_valid(child):
			var zombie_domain: Object = child.get("domain_entity")
			if zombie_domain != null and not zombie_domain.get("is_dead"):
				var child_pos: Vector3 = child.get("global_position")
				var dist_sq := host_pos.distance_squared_to(child_pos)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_threat = child
					
	return closest_threat


## Look-Ahead Validator: Ensures terrestrial wildlife doesn't drown and aquatic stays constrained
func _is_direction_safe_fauna(host: Object, dir: Vector3) -> bool:
	var world_node: Node = null
	if host.has_method("get_parent"):
		world_node = host.call("get_parent") as Node
		
	if not is_instance_valid(world_node) or not "world_state" in world_node:
		return true
		
	var ws: WorldState = world_node.world_state
	if ws == null:
		return true
		
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 1.5
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	var block_below: int = ws.get_block(block_below_coord)
	var block_at: int = ws.get_block(block_at_coord)
	
	var habitat: int = 0
	if host.has_method("_get_habitat"):
		habitat = host.call("_get_habitat") as int
		
	# Block mappings (mirrors of BlockType.Type): WATER = 6, LAVA = 15, SAND = 7, MUD = 11, AIR = 0
	if habitat == 2: # AQUATIC
		return block_below == 6 or block_at == 6
	elif habitat == 1: # AMPHIBIOUS
		var is_water := block_below == 6 or block_at == 6
		var is_shore := block_below == 7 or block_below == 11
		return is_water or is_shore
	else: # TERRESTRIAL
		var is_water := block_below == 6 or block_below == 15 or block_at == 6
		var is_void := block_below == 0
		
		if is_void:
			var block_2_below: int = ws.get_block(block_below_coord + Vector3i(0, -1, 0))
			if block_2_below != 0 and block_2_below != 6 and block_2_below != 15:
				is_void = false
				
		return not is_water and not is_void
