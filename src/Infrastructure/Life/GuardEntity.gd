# ==============================================================================
# Project: CraftDomain
# Description: Elite Guard NPC physics controller with dynamic visual strategy injection.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles exclusively combat AI 
#                and knightly physics, delegating all rendering/mesh tasks.
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity cleanly.
#              - Dependency Inversion Principle (DIP): Visual structures are completely 
#                delegated to the injected `IEntityVisualRepresentation` strategy.
# WARNING RESOLUTION:
#              - Removed redundant duplicate "ANIM_DIR" constant definition to 
#                prevent subclass collision compilation errors.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GuardEntity.gd
# ==============================================================================
class_name GuardEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/guard/guard_base.fbx"

# Combat settings
const ATTACK_RANGE: float = 1.6
const ATTACK_RANGE_SQ: float = 2.56 # 1.6 * 1.6
const AGGRO_SIGHT_RANGE: float = 10.0
const AGGRO_SIGHT_RANGE_SQ: float = 100.0 # 10.0 * 10.0
const ATTACK_COOLDOWN_INTERVAL: float = 1.2 # Time between slashes

# Active combat targets
var _combat_target: CharacterBody3D = null
var _attack_cooldown_timer: float = 0.0

# Asynchronous Scan Throttling Timer
var _tactical_scan_timer: float = 0.0
const SCAN_INTERVAL: float = 0.25 # 4 times per second


func _init(spawn_pos: Vector3) -> void:
	# Initialize with 5 Hearts of health for elite durability (10 HP)
	super(spawn_pos, 10)
	name = "Entity_GUARD"
	_tactical_scan_timer = randf_range(0.0, SCAN_INTERVAL)


## Concrete Implementation (DIP): Injects the modular Guard Role ID into the strategy compiler
func _get_humanoid_role() -> int:
	return ProceduralVoxelRepresentation.RoleType.GUARD


## Overrides standard physics ticker to weave defensive aggro scanning loops.
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
		
	_process_defensive_aggro_intelligence(delta)
	super(delta)


## Coordinates dynamic physical sweeps
func _process_defensive_aggro_intelligence(delta: float) -> void:
	# ==========================================================================
	# TACTICAL PROXIMITY SCAN (Throttled for Performance)
	# ==========================================================================
	_tactical_scan_timer -= delta
	if _tactical_scan_timer <= 0.0:
		_tactical_scan_timer = SCAN_INTERVAL
		
		# Scan for nearest threat if currently un-engaged
		if not is_instance_valid(_combat_target) or _combat_target.get("domain_entity").is_dead:
			_combat_target = _scan_for_active_zombie_target()
			
	# ==========================================================================
	# ACTIVE COMBAT PURSUIT
	# ==========================================================================
	if is_instance_valid(_combat_target) and not _combat_target.get("domain_entity").is_dead:
		# Lock standard wandering AI decisions
		if is_instance_valid(ai_component):
			ai_component.current_task = NPCAIComponent.TaskState.WORKING
			
		var target_pos := _combat_target.global_position
		var diff := target_pos - global_position
		diff.y = 0.0
		
		# MATH OPTIMIZATION: Compare squared length to avoid sqrt() operations
		var dist_sq := diff.length_squared()
		
		if dist_sq > ATTACK_RANGE_SQ:
			# Chase at high-pursuit run speed (Read vector, override ai_component velocity)
			var wander_dir := diff.normalized()
			velocity.x = wander_dir.x * BASE_SPEED * 1.8
			velocity.z = wander_dir.z * BASE_SPEED * 1.8
			
			if is_instance_valid(ai_component):
				ai_component.wander_direction = wander_dir
			
			# Jump over small obstacles
			if is_on_wall() and is_on_floor():
				velocity.y = JUMP_VELOCITY
		else:
			# In-range: Halt and swing!
			velocity.x = 0.0
			velocity.z = 0.0
			
			if is_instance_valid(ai_component):
				ai_component.wander_direction = diff.normalized()
			
			if _attack_cooldown_timer <= 0.0:
				_execute_combat_strike()
	else:
		if is_instance_valid(ai_component) and ai_component.current_task == NPCAIComponent.TaskState.WORKING:
			ai_component.current_task = NPCAIComponent.TaskState.IDLE
			ai_component.task_timer = 1.0


## Trigonometric Scan: Locates the closest active zombie within combat range.
func _scan_for_active_zombie_target() -> CharacterBody3D:
	if not is_inside_tree():
		return null
		
	var closest_zombie: CharacterBody3D = null
	var min_dist_sq := AGGRO_SIGHT_RANGE_SQ
	
	# HIGH PERFORMANCE GROUP QUERY
	var hostiles := get_tree().get_nodes_in_group("hostiles")
	for child: Node in hostiles:
		if is_instance_valid(child):
			var zombie_entity: VoxelEntity = child.get("domain_entity") as VoxelEntity
			if zombie_entity != null and not zombie_entity.is_dead:
				var dist_sq := global_position.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_zombie = child as CharacterBody3D
					
	return closest_zombie


## Executes sword slash calculations against the target zombie.
func _execute_combat_strike() -> void:
	if not is_instance_valid(_combat_target) or _combat_target.get("domain_entity").is_dead:
		return
		
	_attack_cooldown_timer = ATTACK_COOLDOWN_INTERVAL
	
	# Apply diagonal physical knockback force
	var wander_dir := _combat_target.global_position - global_position
	wander_dir.y = 0.0
	wander_dir = wander_dir.normalized()
	
	var knockback_dir := wander_dir * 4.5
	knockback_dir.y = 2.0
	
	# Deal 1 Heart damage (Zombies have 3 Hearts and die in 3 hits)
	if _combat_target.has_method("take_damage"):
		_combat_target.call("take_damage", 1, knockback_dir)
		
	# SOLID: Delegate attack visuals directly to the injected visual strategy
	if is_instance_valid(visual_representation):
		visual_representation.trigger_attack_visuals()


## Queries coordinate biomes.
func _detect_current_biome() -> int:
	var world_controller_ref: Node = get_parent() as Node
	var default_biome_id: int = 2
	
	if is_instance_valid(world_controller_ref) and "generator" in world_controller_ref:
		var generator: WorldGenerator = world_controller_ref.get("generator") as WorldGenerator
		if generator != null:
			var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
			if terrain_noise != null:
				var profile := BiomeService.evaluate_coordinate(
					int(round(global_position.x)), 
					int(round(global_position.z)), 
					terrain_noise
				)
				return profile.biome_id
				
	return default_biome_id


func _can_socialize() -> bool:
	return _combat_target == null
