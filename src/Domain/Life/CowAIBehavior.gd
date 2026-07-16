# ==============================================================================
# Pathfile: res://src/Domain/Life/CowAIBehavior.gd
# Description: Pure Domain AI behavior strategy implementing specialized 
#              grazing, milk regrowth, and ponderous walking routines for the Clay Cow.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly cow state 
#   transitions, grazing checks, and milk regeneration conditions.
# - Layered DDD Compliance: Pure logical state calculations with zero framework 
#   leakage, keeping physics and velocity implementations in Infrastructure.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CowAIBehavior
extends IAIBehavior

const SPEED_WALK: float = 0.6
const SPEED_PANIC: float = 1.8
const SENSORY_RANGE_SQ: float = 64.0 # 8.0m threat detection radius

# Grazing duration parameters
const GRAZE_INTERVAL_MIN_SEC: float = 15.0
const GRAZE_INTERVAL_MAX_SEC: float = 30.0
const GRAZE_DURATION_SEC: float = 3.0

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Specialized Cow States: 0 = WANDERING, 1 = GRAZING
const STATE_WANDERING = 0
const STATE_GRAZING = 1

# Decoupled metadata keys
const META_STATE := "cow_local_state"
const META_WANDER_TIMER := "cow_wander_timer"
const META_WANDER_DIR := "cow_wander_dir"
const META_GRAZE_TIMER := "cow_graze_timer"
const META_GRAZE_COOLDOWN := "cow_graze_cooldown"
const META_HAS_MILK := "cow_has_milk"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives grazing, soil-munching, and milk regrowth cycles
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	_update_cooldowns(host, delta)
	
	var is_panicking := _evaluate_threat_panic(host)
	if is_panicking:
		_process_panic_state(host, delta)
		return
		
	var state: int = host.get_meta(META_STATE) as int
	match state:
		STATE_GRAZING:
			_process_grazing_state(host, delta)
		STATE_WANDERING:
			_process_wandering_state(host, delta)


func _update_cooldowns(host: Object, delta: float) -> void:
	var cooldown: float = host.get_meta(META_GRAZE_COOLDOWN) as float
	if cooldown > 0.0:
		host.set_meta(META_GRAZE_COOLDOWN, cooldown - delta)


func _evaluate_threat_panic(host: Object) -> bool:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return false
		
	var is_panicking := ai.get("current_task") as int == TASK_PANIC
	var parent: Node = host.call("get_parent") as Node
	
	# Proximity scan for active hostiles in the scene tree
	if not is_panicking and is_instance_valid(parent):
		var hostiles: Array = []
		if host.has_method("get_tree"):
			var tree: Object = host.call("get_tree")
			if is_instance_valid(tree):
				hostiles = tree.call("get_nodes_in_group", "hostiles")
				
		var host_pos: Vector3 = host.get("global_position")
		for child: Object in hostiles:
			if is_instance_valid(child) and child.get("global_position").distance_squared_to(host_pos) <= SENSORY_RANGE_SQ:
				var z_domain: Object = child.get("domain_entity")
				if z_domain != null and not z_domain.get("is_dead"):
					is_panicking = true
					ai.set("current_task", TASK_PANIC)
					break
					
	return is_panicking


func _process_panic_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	wander_timer -= delta
	
	if wander_timer <= 0.0:
		wander_timer = randf_range(0.5, 1.2) # Heavy animal panic turn frequency
		var angle := randf() * TAU
		host.set_meta(META_WANDER_DIR, Vector3(cos(angle), 0.0, sin(angle)))
		
	host.set_meta(META_WANDER_TIMER, wander_timer)
	host.set_meta(META_STATE, STATE_WANDERING)


func _process_wandering_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	ai.set("current_task", TASK_WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	wander_timer -= delta
	
	if wander_timer <= 0.0:
		_calculate_next_wander_step(host)
		wander_timer = randf_range(3.0, 6.0)
		
	host.set_meta(META_WANDER_TIMER, wander_timer)


func _calculate_next_wander_step(host: Object) -> void:
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	var host_pos: Vector3 = host.get("global_position")
	var cooldown: float = host.get_meta(META_GRAZE_COOLDOWN) as float
	var has_milk: bool = host.get_meta(META_HAS_MILK) as bool
	
	# Milked cows actively search for Grass to digest and regrow milk
	if ws != null and not has_milk and cooldown <= 0.0 and randf() < 0.45:
		var check_coord := Vector3i(floori(host_pos.x), floori(host_pos.y - 0.5), floori(host_pos.z))
		if ws.get_block(check_coord) == 3: # 3 = Grass Block
			host.set_meta(META_STATE, STATE_GRAZING)
			host.set_meta(META_GRAZE_TIMER, GRAZE_DURATION_SEC)
			host.set_meta(META_WANDER_DIR, Vector3.ZERO)
			return
			
	var angle := randf() * TAU
	host.set_meta(META_WANDER_DIR, Vector3(cos(angle), 0.0, sin(angle)) if randf() < 0.4 else Vector3.ZERO)


func _process_grazing_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	ai.set("current_task", TASK_WORKING)
	ai.set("wander_direction", Vector3.ZERO)
	
	var graze_timer: float = host.get_meta(META_GRAZE_TIMER) as float
	graze_timer -= delta
	
	if graze_timer <= 0.0:
		_complete_soil_grazing(host)
	else:
		host.set_meta(META_GRAZE_TIMER, graze_timer)


func _complete_soil_grazing(host: Object) -> void:
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	var host_pos: Vector3 = host.get("global_position")
	
	if ws != null and parent.has_method("set_block_globally"):
		var block_below_coord := Vector3i(floori(host_pos.x), floori(host_pos.y - 0.5), floori(host_pos.z))
		
		# Turns Grass (3) into Dirt (2) and regrows nutritious milk (has_milk = true)
		if ws.get_block(block_below_coord) == 3:
			parent.call("set_block_globally", block_below_coord, 2) # 2 = Dirt Block
			host.set_meta(META_HAS_MILK, true)
			if host.has_method("_play_grazing_joy_hop"):
				host.call("_play_grazing_joy_hop")
				
	# Restart grazing cooldown (15s to 30s)
	host.set_meta(META_GRAZE_COOLDOWN, randf_range(GRAZE_INTERVAL_MIN_SEC, GRAZE_INTERVAL_MAX_SEC))
	host.set_meta(META_STATE, STATE_WANDERING)
	host.set_meta(META_WANDER_TIMER, 1.0)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_STATE): host.set_meta(META_STATE, STATE_WANDERING)
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_GRAZE_TIMER): host.set_meta(META_GRAZE_TIMER, 0.0)
	if not host.has_meta(META_GRAZE_COOLDOWN): host.set_meta(META_GRAZE_COOLDOWN, 8.0) # Grace period on spawn
	if not host.has_meta(META_HAS_MILK): host.set_meta(META_HAS_MILK, true) # Spawns with milk ready


func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_STATE):
		return "WANDER"
		
	var state_val: int = host.get_meta(META_STATE) as int
	match state_val:
		STATE_GRAZING: return "WORKING" # Maps to "ACTIVE WORKING RITUAL" on UI
		_: return "WANDER"
