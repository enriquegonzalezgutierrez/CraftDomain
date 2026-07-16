# ==============================================================================
# Pathfile: res://src/Domain/Life/ChickenAIBehavior.gd
# Description: Pure Domain AI behavior strategy implementing specialized 
#              soil-pecking and panic-fluttering routines for the Prairie Chicken.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly chicken state 
#   transitions, pecking intervals, and panic flutters.
# - Layered DDD Compliance: Pure logical state calculations with zero framework 
#   leakage, keeping physics and velocity implementations in Infrastructure.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChickenAIBehavior
extends IAIBehavior

const SPEED_WANDER: float = 0.9
const SPEED_PANIC: float = 2.2
const SENSORY_RANGE_SQ: float = 64.0 # 8.0m detection radius

# Pecking duration parameters
const PECK_INTERVAL_MIN_SEC: float = 10.0
const PECK_INTERVAL_MAX_SEC: float = 20.0
const PECK_DURATION_SEC: float = 1.6

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Specialized Chicken States: 0 = WANDERING, 1 = PECKING
const STATE_WANDERING = 0
const STATE_PECKING = 1

# Decoupled metadata keys
const META_STATE := "chicken_local_state"
const META_WANDER_TIMER := "chicken_wander_timer"
const META_WANDER_DIR := "chicken_wander_dir"
const META_PECK_TIMER := "chicken_peck_timer"
const META_PECK_COOLDOWN := "chicken_peck_cooldown"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives grazing, soil-pecking, and panic escape cycles
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
		STATE_PECKING:
			_process_pecking_state(host, delta)
		STATE_WANDERING:
			_process_wandering_state(host, delta)


func _update_cooldowns(host: Object, delta: float) -> void:
	var cooldown: float = host.get_meta(META_PECK_COOLDOWN) as float
	if cooldown > 0.0:
		host.set_meta(META_PECK_COOLDOWN, cooldown - delta)


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
		wander_timer = randf_range(0.3, 0.6) # High frequency direction changes
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
		wander_timer = randf_range(1.5, 4.0)
		
	host.set_meta(META_WANDER_TIMER, wander_timer)


func _calculate_next_wander_step(host: Object) -> void:
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	var host_pos: Vector3 = host.get("global_position")
	var cooldown: float = host.get_meta(META_PECK_COOLDOWN) as float
	
	# Verify if standing on Grass or Dirt and pecking cooldown is cleared
	if ws != null and cooldown <= 0.0 and randf() < 0.45:
		var check_coord := Vector3i(floori(host_pos.x), floori(host_pos.y - 0.5), floori(host_pos.z))
		var block := ws.get_block(check_coord)
		if block == 3 or block == 2: # 3 = Grass, 2 = Dirt
			host.set_meta(META_STATE, STATE_PECKING)
			host.set_meta(META_PECK_TIMER, PECK_DURATION_SEC)
			host.set_meta(META_WANDER_DIR, Vector3.ZERO)
			return
			
	var angle := randf() * TAU
	host.set_meta(META_WANDER_DIR, Vector3(cos(angle), 0.0, sin(angle)) if randf() < 0.6 else Vector3.ZERO)


func _process_pecking_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	ai.set("current_task", TASK_WORKING)
	ai.set("wander_direction", Vector3.ZERO)
	
	var peck_timer: float = host.get_meta(META_PECK_TIMER) as float
	peck_timer -= delta
	
	if peck_timer <= 0.0:
		# Restart pecking cooldown
		host.set_meta(META_PECK_COOLDOWN, randf_range(PECK_INTERVAL_MIN_SEC, PECK_INTERVAL_MAX_SEC))
		host.set_meta(META_STATE, STATE_WANDERING)
		host.set_meta(META_WANDER_TIMER, 1.0)
	else:
		host.set_meta(META_PECK_TIMER, peck_timer)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_STATE): host.set_meta(META_STATE, STATE_WANDERING)
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_PECK_TIMER): host.set_meta(META_PECK_TIMER, 0.0)
	if not host.has_meta(META_PECK_COOLDOWN): host.set_meta(META_PECK_COOLDOWN, 4.0) # Grace period on spawn


func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_STATE):
		return "WANDER"
		
	var state_val: int = host.get_meta(META_STATE) as int
	match state_val:
		STATE_PECKING: return "WORKING" # Maps to "ACTIVE WORKING RITUAL" on UI
		_: return "WANDER"
