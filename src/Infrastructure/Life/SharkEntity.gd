# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a hostile marine Shark.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Inherits cleanly from 
#                PassiveEntity to share physics, colliders, and death sequences, 
#                but safely disables the passive AI component in _ready().
#              - Dependency Inversion Principle (DIP): Uses the modular 
#                FaunaVisualRepresentation strategy, eliminating tons of duplicated
#                rendering setup code.
# HABITAT-DRIVEN SPAWNING (DDD Compliance):
#              - Overrides `_get_habitat()` to return AQUATIC, ensuring it 
#                spawns strictly submerged in deep water.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/SharkEntity.gd
# ==============================================================================
class_name SharkEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/shark.glb"

# Combat configurations
const SPEED: float = 3.5
const CHASE_RANGE_SQ: float = 256.0 # 16m squared
const ATTACK_RANGE_SQ: float = 2.25 # 1.5m squared
const ATTACK_COOLDOWN_INTERVAL: float = 1.5

# Sibling node references
var player: CharacterBody3D

# AI wandering/chasing state variables
var _wander_timer: float = 0.0
var _wander_direction: Vector3 = Vector3.ZERO
var _is_wandering: bool = false
var _attack_cooldown_timer: float = 0.0

# Procedural Swimming Animation tracker
var _animation_time: float = 0.0


func _init(spawn_pos: Vector3) -> void:
	# Sharks have 4 Hearts of health (8 HP)
	super(spawn_pos, 8)
	name = "Entity_SHARK"


func _ready() -> void:
	super()
	
	# Transition from passive group to hostiles
	remove_from_group("passives")
	add_to_group("hostiles")
	
	# Hostiles use aggressive custom AI, so we safely detach the civilian AI
	if is_instance_valid(ai_component):
		ai_component.queue_free()
		ai_component = null
		
	# Paint the inherited nameplate in Warning Crimson Red!
	if is_instance_valid(_nameplate):
		_nameplate.modulate = Color(1.0, 0.15, 0.15)
		
	_locate_player()


# ==============================================================================
# POLYMORPHIC DOMAIN CONTRACTS (LSP/OCP COMPLIANCE)
# ==============================================================================

func _get_habitat() -> MobRegistry.Habitat:
	return MobRegistry.Habitat.AQUATIC


func _has_ui_decorations() -> bool:
	return true # We force it true to ensure the red nameplate spawns!


## Concrete Implementation (DIP): Instantiates and injects the Fauna Strategy dynamically
func _build_visual_representation() -> void:
	var strategy := FaunaVisualRepresentation.new()
	strategy.model_path = MODEL_PATH
	
	# Scale and position offsets calculated via GLB Analyzer V5
	strategy.scale_multiplier = Vector3(1.8366, 1.8366, 1.8366)
	strategy.position_offset = Vector3(0.0, -0.5328, 0.0)
	strategy.rotation_offset = Vector3(0, -90, 0) # Face forward (-Z)
	
	# Physical collision bounds
	strategy.collision_size = Vector3(0.85, 1.80, 1.10)
	strategy.collision_position = Vector3(0.0, 0.9, 0.0)
	
	# Inject strategy into parent coordinator (Animations skipped as shark swims procedurally)
	visual_representation = strategy
	visual_representation.build_representation(self, visual_component.body_bob_node)


# ==============================================================================
# COMBAT & LOOT LOGIC
# ==============================================================================

func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


## Override: Hostiles do not panic when hit, they charge forward!
func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


## Drops 1x Sand Block on death
func _drop_loot(inv: IInventory) -> void:
	# Item ID 7: Sand Block
	inv.add_item(7, 1)


# ==============================================================================
# PROCEDURAL SWIMMING ENGINE (Sinusoidal Tail-Wagging)
# ==============================================================================
func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var model_node := visual_component.body_bob_node.get_child(0) as Node3D
	if is_instance_valid(model_node):
		_animation_time += delta
		
		var flat_velocity := Vector2(velocity.x, velocity.z)
		var is_moving := flat_velocity.length_squared() > 0.1
		
		if is_moving:
			# Fast tail wagging when swimming rapidly (Yaw oscillation on Z-axis offset)
			var swim_speed := flat_velocity.length() * 2.5
			model_node.rotation.y = deg_to_rad(-90.0) + sin(_animation_time * swim_speed) * 0.22
			model_node.rotation.z = cos(_animation_time * swim_speed * 0.5) * 0.08 
		else:
			# Calm, idle ocean current swaying
			model_node.rotation.y = lerp(model_node.rotation.y, deg_to_rad(-90.0), delta * 5.0)
			model_node.rotation.z = sin(_animation_time * 1.5) * 0.03


# ==============================================================================
# MAIN PHYSICS & SWIMMING AI CALCULATIONS
# ==============================================================================
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return

	# No gravity applied: sharks swim neutrally in the water column
	velocity.y = move_toward(velocity.y, 0, SPEED * delta)

	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	if not is_instance_valid(player):
		_locate_player()

	_process_ai_intelligence(delta)
	move_and_slide()


func _process_ai_intelligence(delta: float) -> void:
	var _wander_direction_tmp: Vector3 = Vector3.ZERO
	_wander_timer -= delta
	if _wander_timer <= 0:
		_is_wandering = randf() > 0.4
		if _is_wandering:
			var angle := randf() * TAU
			_wander_direction_tmp = Vector3(cos(angle), 0, sin(angle))
			_wander_timer = randf_range(2.0, 5.0)
		else:
			_wander_direction_tmp = Vector3.ZERO
			_wander_timer = randf_range(1.0, 3.0)
			
	var is_player_trackable: bool = false
	if is_instance_valid(player) and bool(player.get("is_active")):
		var dist_sq := global_position.distance_squared_to(player.global_position)
		if dist_sq < CHASE_RANGE_SQ:
			_is_wandering = true
			_wander_direction = (player.global_position - global_position).normalized()
			_wander_direction.y = 0
			is_player_trackable = true
			
			if dist_sq <= ATTACK_RANGE_SQ:
				if _attack_cooldown_timer <= 0.0:
					_bite_player()
					_attack_cooldown_timer = ATTACK_COOLDOWN_INTERVAL
				
	if not is_player_trackable and _wander_direction_tmp != Vector3.ZERO:
		_wander_direction = _wander_direction_tmp

	if _is_wandering:
		var speed_mult: float = SPEED if is_player_trackable else (SPEED * 0.5)
		velocity.x = _wander_direction.x * speed_mult
		velocity.z = _wander_direction.z * speed_mult
		
		var visuals_node: Node3D = get_node_or_null("NPCVisualComponent/Visuals") as Node3D
		if is_instance_valid(visuals_node) and _wander_direction.length_squared() > 0.01:
			var target_look_at: Vector3 = global_position + _wander_direction
			if not global_position.is_equal_approx(target_look_at):
				var current_rot_x := visuals_node.rotation.x
				var current_rot_z := visuals_node.rotation.z
				visuals_node.look_at(target_look_at, Vector3.UP)
				visuals_node.rotation.x = current_rot_x
				visuals_node.rotation.z = current_rot_z
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)


func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(dir.x * 5.5, 0.25, dir.z * 5.5)
		if player.has_method("take_damage"):
			player.call("take_damage", 1, knockback)
