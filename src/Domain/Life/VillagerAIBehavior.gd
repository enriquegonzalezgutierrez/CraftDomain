# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: VillagerAIBehavior
# Description: Specialized AI behavior strategy implementing social life routines for
#              the Common Villager NPC. Coordinates real-time group "gossiping" 
#              (seeking nearby peer villagers to stand and chat in circles), 
#              and dynamic day/night shelter-seeking scheduling.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly social gossip cycles,
#   night retreats, and coordinate orientations, keeping physical rigs separated.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. New emotes, tilling, or
#   village reputation actions can be appended cleanly here.
# - Liskov Substitution Principle (LSP): Fully compatible with the contract signatures.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/VillagerAIBehavior.gd
# ==============================================================================
class_name VillagerAIBehavior
extends IAIBehavior

const SPEED_PATROL: float = 1.0
const SPEED_RETREAT: float = 1.6
const COOLDOWN_CHAT_SEC: float = 8.0
const CHAT_DURATION_SEC: float = 4.0

const RANGE_SIGHT_SQ: float = 36.0 # 6.0 meters squared peer search radius

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_WANDER_TIMER := "villager_wander_timer"
const META_WANDER_DIR := "villager_wander_dir"
const META_PEER := "villager_peer_target"
const META_COOLDOWN := "villager_chat_cooldown"
const META_CHAT_TIMER := "villager_chat_timer"


func _init() -> void:
	# Villagers manage their schedules and paths completely
	overrides_wandering = true


## Concrete Contract: Drives daily gossip walks, night retreats, and chat animations
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	# Skip routines if talking to the real player
	if host.get("is_talking") == true:
		_reset_villager_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var chat_cooldown: float = host.get_meta(META_COOLDOWN) as float
	
	var target_ref: Object = null
	if host.has_meta(META_PEER):
		var val: Variant = host.get_meta(META_PEER)
		if typeof(val) == TYPE_OBJECT:
			var obj: Object = val
			if is_instance_valid(obj):
				target_ref = obj
				
	var chat_timer: float = host.get_meta(META_CHAT_TIMER) as float
	
	if chat_cooldown > 0.0:
		chat_cooldown -= delta
		host.set_meta(META_COOLDOWN, chat_cooldown)
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	var host_pos: Vector3 = host.get("global_position")
	var parent: Node = host.call("get_parent") as Node
	var is_night: bool = CelestialService.is_night_time_static()

	# ==========================================================================
	# 1. SPECIAL EMERGENCY STATE: NIGHT / STORM SHELTER RETREAT
	# ==========================================================================
	var is_storming := false
	if is_instance_valid(parent):
		var weather_node: Node = parent.get_node_or_null("WeatherService")
		if is_instance_valid(weather_node):
			var cur_weather: int = int(weather_node.get("current_weather"))
			is_storming = (cur_weather == 1 or cur_weather == 2) # Rain or Snow

	if is_night or is_storming:
		_reset_villager_state(host)
		
		# Check if already inside a roofed shelter node
		var is_inside := false
		var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
		var nav_service: Object = parent.get("navigation_service") if is_instance_valid(parent) else null
		
		if is_instance_valid(nav_service) and "_indoor_nodes" in nav_service:
			var indoor_nodes: Array = nav_service.get("_indoor_nodes") as Array
			is_inside = indoor_nodes.has(my_coord)
			
		if is_inside:
			# Cozy warm inside: halt translations, stand and sleep
			ai.set("current_task", TASK_IDLE)
			velocity.x = 0.0
			velocity.z = 0.0
			host.set("velocity", velocity)
			ai.set("wander_direction", Vector3.ZERO)
		else:
			# Outside! Calculate rapid A* path inside the closest cabin/inn
			if is_instance_valid(nav_service) and nav_service.has_method("find_closest_shelter_node"):
				var shelter_pos: Vector3 = nav_service.call("find_closest_shelter_node", host_pos)
				if shelter_pos != Vector3.ZERO:
					var diff := shelter_pos - host_pos
					diff.y = 0.0
					if diff.length() > 0.8:
						var run_dir := diff.normalized()
						velocity.x = run_dir.x * SPEED_RETREAT
						velocity.z = run_dir.z * SPEED_RETREAT
						host.set("velocity", velocity)
						ai.set("wander_direction", run_dir)
						ai.set("current_task", TASK_WANDERING)
						return
						
			# Fallback: halt
			velocity.x = 0.0
			velocity.z = 0.0
			host.set("velocity", velocity)
		return

	# ==========================================================================
	# 2. CHISMORREO STATE: ACTIVE GROUP GOSSIP (Y=11/12)
	# ==========================================================================
	if is_instance_valid(target_ref):
		var target_node := target_ref as Node3D
		var target_domain: Object = target_node.get("domain_entity")
		
		# Cancel chat if peer goes missing/dies
		if target_domain == null or target_domain.get("is_dead") == true:
			_reset_villager_state(host)
			return
			
		ai.set("current_task", TASK_WORKING)
		
		var target_pos: Vector3 = target_node.global_position
		var diff := target_pos - host_pos
		diff.y = 0.0
		var dist_sq := diff.length_squared()
		
		if dist_sq > 2.5:
			# Walk to join the gossip circle
			var gather_dir := diff.normalized()
			velocity.x = gather_dir.x * SPEED_PATROL
			velocity.z = gather_dir.z * SPEED_PATROL
			host.set("velocity", velocity)
			ai.set("wander_direction", gather_dir)
		else:
			# Arrived! Halt, face peer, play meow dialogue chatter
			velocity.x = 0.0
			velocity.z = 0.0
			host.set("velocity", velocity)
			ai.set("wander_direction", diff.normalized())
			
			chat_timer -= delta
			if chat_timer <= 0.0:
				# Gossip completed! Set long cooldown on next chat
				host.set_meta(META_COOLDOWN, COOLDOWN_CHAT_SEC)
				_reset_villager_state(host)
				return
				
			# Trigger verbal chatter murmurs in presenter (cooldown 1s)
			if int(round(chat_timer * 10.0)) % 15 == 0:
				if host.has_method("_play_gossip_chatter"):
					host.call("_play_gossip_chatter")
					
			host.set_meta(META_CHAT_TIMER, chat_timer)
		return

	# ==========================================================================
	# 3. PROXIMITY SCANNING: SEEK PEER CITIZENS (Only when chat off cooldown)
	# ==========================================================================
	if chat_cooldown <= 0.0:
		var peer_citizen := _scan_for_nearby_peer(host)
		if peer_citizen != null:
			host.set_meta(META_PEER, peer_citizen)
			host.set_meta(META_CHAT_TIMER, CHAT_DURATION_SEC)
			return

	# ==========================================================================
	# 4. DEFAULT PEACEFUL PATROL (Village roaming)
	# ==========================================================================
	ai.set("current_task", TASK_WANDERING)
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 5.0)
		if randf() < 0.45:
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
		else:
			wander_dir = Vector3.ZERO
			
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)

	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * SPEED_PATROL
		velocity.z = wander_dir.z * SPEED_PATROL
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_PATROL)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_PATROL)
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_PEER):
		host.set_meta(META_PEER, "")
	if not host.has_meta(META_COOLDOWN):
		host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_CHAT_TIMER):
		host.set_meta(META_CHAT_TIMER, 0.0)


func _reset_villager_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_PEER, "")
	host.set_meta(META_CHAT_TIMER, 0.0)
	host.set_meta(META_WANDER_TIMER, 1.0)


## Proximity Scanner: Scans for active fellow humanoids to chat with
func _scan_for_nearby_peer(host: Object) -> Node3D:
	if not host.call("is_inside_tree"):
		return null
		
	var passives: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			passives = tree.call("get_nodes_in_group", "passives")
			
	var host_pos: Vector3 = host.get("global_position")
	var closest_peer: Node3D = null
	var min_dist_sq := RANGE_SIGHT_SQ
	
	for child: Object in passives:
		if is_instance_valid(child) and child != host and child is Node3D:
			var name_str: String = child.get("name")
			# Checks if fellow target is a compatible talking citizen role
			if name_str.contains("VILLAGER") or name_str.contains("MERCHANT") or name_str.contains("FARMER") or name_str.contains("MINER") or name_str.contains("DRUID"):
				var domain: Object = child.get("domain_entity")
				if domain != null and not domain.get("is_dead"):
					var dist_sq := host_pos.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest_peer = child as Node3D
						
	return closest_peer
