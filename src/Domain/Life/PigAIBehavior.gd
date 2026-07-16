# ==============================================================================
# Pathfile: res://src/Domain/Life/PigAIBehavior.gd
# Description: Pure Domain AI behavior strategy implementing specialized 
#              root-sniffing and grass-tilling routines for the Wild Pig.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly pig state 
#   transitions, tilling checks, and cooldown timers.
# - Layered DDD Compliance: Pure logical state calculations with zero framework 
#   leakage, delegating voxel mutations to the abstract world modifier boundary.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PigAIBehavior
extends IAIBehavior

const SPEED_WALK: float = 0.8
const SPEED_PANIC: float = 2.4
const SENSORY_RANGE_SQ: float = 64.0 # 8.0m threat detection radius

# Sniff and Till duration parameters
const SNIFF_DURATION_SEC: float = 1.5
const TILL_DURATION_SEC: float = 2.0
const COOLDOWN_TILL_MIN_SEC: float = 15.0
const COOLDOWN_TILL_MAX_SEC: float = 30.0

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Specialized Pig States: 0 = WANDERING, 1 = SNIFFING, 2 = TILLING
const STATE_WANDERING = 0
const STATE_SNIFFING = 1
const STATE_TILLING = 2

# Decoupled metadata keys
const META_STATE := "pig_local_state"
const META_WANDER_TIMER := "pig_wander_timer"
const META_WANDER_DIR := "pig_wander_dir"
const META_TILL_TIMER := "pig_till_timer"
const META_TILL_COOLDOWN := "pig_till_cooldown"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives grazing, soil-sniffing, and terrain tilling cycles
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
		STATE_TILLING:
			_process_tilling_state(host, delta)
		STATE_SNIFFING:
			_process_sniffing_state(host, delta)
		STATE_WANDERING:
			_process_wandering_state(host, delta)


func _update_cooldowns(host: Object, delta: float) -> void:
	var cooldown: float = host.get_meta(META_TILL_COOLDOWN) as float
	if cooldown > 0.0:
		host.set_meta(META_TILL_COOLDOWN, cooldown - delta)


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
		wander_timer = randf_range(0.4, 1.0)
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
		wander_timer = randf_range(2.0, 5.0)
		
	host.set_meta(META_WANDER_TIMER, wander_timer)


func _calculate_next_wander_step(host: Object) -> void:
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	var host_pos: Vector3 = host.get("global_position")
	var cooldown: float = host.get_meta(META_TILL_COOLDOWN) as float
	
	# Verify if standing on fertile Grass and tilling cooldown is fully cleared
	if ws != null and cooldown <= 0.0 and randf() < 0.35:
		var check_coord := Vector3i(floori(host_pos.x), floori(host_pos.y - 0.5), floori(host_pos.z))
		if ws.get_block(check_coord) == 3: # 3 = Grass Block
			host.set_meta(META_STATE, STATE_SNIFFING)
			host.set_meta(META_TILL_TIMER, SNIFF_DURATION_SEC)
			host.set_meta(META_WANDER_DIR, Vector3.ZERO)
			return
			
	var angle := randf() * TAU
	host.set_meta(META_WANDER_DIR, Vector3(cos(angle), 0.0, sin(angle)) if randf() < 0.5 else Vector3.ZERO)


func _process_sniffing_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	ai.set("current_task", TASK_IDLE)
	ai.set("wander_direction", Vector3.ZERO)
	
	var till_timer: float = host.get_meta(META_TILL_TIMER) as float
	till_timer -= delta
	
	if till_timer <= 0.0:
		host.set_meta(META_STATE, STATE_TILLING)
		host.set_meta(META_TILL_TIMER, TILL_DURATION_SEC)
	else:
		host.set_meta(META_TILL_TIMER, till_timer)


func _process_tilling_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	ai.set("current_task", TASK_WORKING)
	
	var till_timer: float = host.get_meta(META_TILL_TIMER) as float
	till_timer -= delta
	
	if till_timer <= 0.0:
		_complete_soil_tilling(host)
	else:
		host.set_meta(META_TILL_TIMER, till_timer)


func _complete_soil_tilling(host: Object) -> void:
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	var host_pos: Vector3 = host.get("global_position")
	
	if ws != null and parent.has_method("set_block_globally"):
		var block_below_coord := Vector3i(floori(host_pos.x), floori(host_pos.y - 0.5), floori(host_pos.z))
		
		# 40% probability to dynamically turn Grass (3) into Dirt (2)
		if ws.get_block(block_below_coord) == 3 and randf() < 0.40:
			parent.call("set_block_globally", block_below_coord, 2) # 2 = Dirt Block
			if host.has_method("_play_tilling_joy_hop"):
				host.call("_play_tilling_joy_hop")
				
	# Restart snout-sniffing cooldown (15s to 30s)
	host.set_meta(META_TILL_COOLDOWN, randf_range(COOLDOWN_TILL_MIN_SEC, COOLDOWN_TILL_MAX_SEC))
	host.set_meta(META_STATE, STATE_WANDERING)
	host.set_meta(META_WANDER_TIMER, 1.0)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_STATE): host.set_meta(META_STATE, STATE_WANDERING)
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_TILL_TIMER): host.set_meta(META_TILL_TIMER, 0.0)
	if not host.has_meta(META_TILL_COOLDOWN): host.set_meta(META_TILL_COOLDOWN, 5.0) # Grace period on spawn


func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_STATE):
		return "WANDER"
		
	var state_val: int = host.get_meta(META_STATE) as int
	match state_val:
		STATE_SNIFFING: return "EXAMINE"   # Maps to "EXAMINING ENTORNO" on UI
		STATE_TILLING: return "WORKING"    # Maps to "ACTIVE WORKING RITUAL" on UI
		_: return "WANDER"
