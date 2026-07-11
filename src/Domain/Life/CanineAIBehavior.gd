# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Life & Entities / AI Strategies)
# Class: CanineAIBehavior
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# Description: Specialized AI behavior strategy implementing loyal canine routines
#              for the Fiery Growlithe dog. Features active magma tracking (seeking 
#              surrounding Lava blocks), sitting next to heat vents to play sniff 
#              animations, and triggers continuous fiery ember bark particles.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the canine decision
#   trees, volcanic attractions, and fire bark timers, keeping physical rigs separated.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. New fetch games, 
#   player taming, or sheep herding can be appended cleanly here.
# - Liskov Substitution Principle (LSP): Fully compatible with the contract signatures.
# ==============================================================================
class_name CanineAIBehavior
extends IAIBehavior

const SPEED_WALK: float = 1.0
const SPEED_TROT: float = 1.6
const COOLDOWN_BARK_SEC: float = 4.0

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_WANDER_TIMER := "growlithe_wander_timer"
const META_WANDER_DIR := "growlithe_wander_dir"
const META_BARK_COOLDOWN := "growlithe_bark_cooldown"
const META_TARGET_LAVA := "growlithe_lava_target"


func _init() -> void:
	# Growlithes fully override generic schedules to run canine loops
	overrides_wandering = true


## Concrete Contract: Drives lava tracking, magma sniffing, and flame barking cycles
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var bark_cooldown: float = host.get_meta(META_BARK_COOLDOWN) as float
	var target_lava: Vector3i = host.get_meta(META_TARGET_LAVA) as Vector3i
	
	if bark_cooldown > 0.0:
		bark_cooldown -= delta
		host.set_meta(META_BARK_COOLDOWN, bark_cooldown)
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	var host_pos: Vector3 = host.get("global_position")
	var parent: Node = host.call("get_parent") as Node

	# ==========================================================================
	# 1. HEAT-SEEKING VOLCANIC SNIFFING (Attracted to active Lava ID 15)
	# ==========================================================================
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	
	if ws != null:
		# If no active lava block is targeted, perform thermal ground scans
		if target_lava.y == -999:
			target_lava = _scan_for_nearby_lava(host_pos, ws)
			host.set_meta(META_TARGET_LAVA, target_lava)
			
		# If lava coordinates are targeted, walk to snuggle near the magma
		if target_lava.y != -999:
			ai.set("current_task", TASK_WORKING)
			
			var lava_pos := Vector3(target_lava) + Vector3(0.5, 0.0, 0.5)
			var diff := lava_pos - host_pos
			diff.y = 0.0
			var length := diff.length()
			
			if length > 2.0:
				# Trot happily towards the heat vent
				var trot_dir := diff.normalized()
				velocity.x = trot_dir.x * SPEED_TROT
				velocity.z = trot_dir.z * SPEED_TROT
				host.set("velocity", velocity)
				ai.set("wander_direction", trot_dir)
			else:
				# Arrived: sit and sniff the magma, wag tail and bark fiery sparks!
				velocity.x = 0.0
				velocity.z = 0.0
				host.set("velocity", velocity)
				ai.set("wander_direction", diff.normalized())
				
				if bark_cooldown <= 0.0:
					bark_cooldown = COOLDOWN_BARK_SEC
					host.set_meta(META_BARK_COOLDOWN, bark_cooldown)
					
					# Call flame bark audio/sparks inside presentation layer
					if host.has_method("_play_flame_bark"):
						host.call("_play_flame_bark")
			return

	# ==========================================================================
	# 2. DEFAULT PLAYFUL GRASS WANDERING
	# ==========================================================================
	ai.set("current_task", TASK_WANDERING)
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		
		# sniffs the grass: 50% chance to trot, 50% to play in tail-chasing circles
		var roll := randf()
		if roll < 0.4:
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
		elif roll < 0.65:
			# Playful tail chasing: force spin velocity
			var angle: float = float(Time.get_ticks_msec() / 100.0)
			wander_dir = Vector3(cos(angle), 0.0, sin(angle)).normalized()
			wander_timer = 1.5 # short dizzy timing
		else:
			wander_dir = Vector3.ZERO
			
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)

	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * SPEED_WALK
		velocity.z = wander_dir.z * SPEED_WALK
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_WALK)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_WALK)
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_BARK_COOLDOWN):
		host.set_meta(META_BARK_COOLDOWN, 0.0)
	if not host.has_meta(META_TARGET_LAVA):
		host.set_meta(META_TARGET_LAVA, Vector3i(0, -999, 0))


## Proximity Scanner: Scans a 3D grid looking for glowing Lava blocks (ID 15)
func _scan_for_nearby_lava(host_pos: Vector3, ws: WorldState) -> Vector3i:
	var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
	
	# Scans in a 5x5 column area
	for x: int in range(-5, 6):
		for y: int in range(-2, 3):
			for z: int in range(-5, 6):
				var check_coord := my_coord + Vector3i(x, y, z)
				# Block ID 15 is Volatile Molten Lava (LAVA)
				if ws.get_block(check_coord) == 15:
					return check_coord
					
	return Vector3i(0, -999, 0)
