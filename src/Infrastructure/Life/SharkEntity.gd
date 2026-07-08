# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Description: Physics controller for the hostile marine Shark, designed to be
#              attached to a '.tscn' scene file.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively active
#                swimming physics, scent tracking, and biting logic, delegating
#                visual and collision parameters to the Godot Editor.
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity,
#                swapping groups cleanly without code-based instantiation.
#              CIRCULAR DEPENDENCY SHIELD:
#              - Changed '_get_habitat()' return signature to 'int' to safely break
#                the GDScript compilation lock with MobRegistry class name.
#              STABILIZATION:
#              - Removed redundant signal connections already handled in parent class.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/SharkEntity.gd
# ==============================================================================
class_name SharkEntity
extends PassiveEntity

# Sibling node references
var player: CharacterBody3D

# AI and state trackers
var _wander_timer: float = 0.0
var _wander_direction: Vector3 = Vector3.ZERO
var _is_wandering: bool = false
var _attack_cooldown_timer: float = 0.0
var _animation_time: float = 0.0

# Dynamic cached reference to visual model
var _model_node: Node3D

# Combat configurations
const SPEED: float = 3.5
const CHASE_RANGE_SQ: float = 256.0 # 16m squared
const ATTACK_RANGE_SQ: float = 2.25 # 1.5m squared
const ATTACK_COOLDOWN_INTERVAL: float = 1.5


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Sharks have 4 Hearts of health (8 HP)
	super(spawn_pos, 8)
	name = "Entity_SHARK"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the hostile group for O(1) targeting
	add_to_group("hostiles")
	
	# Cache component references pre-configured in the scene (No AI Component needed for hostiles)
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/shark") as Node3D
	
	# Hostile nameplate warning coloring (Warning Crimson Red!)
	if is_instance_valid(_nameplate):
		_nameplate.modulate = Color(1.0, 0.15, 0.15)
		
	_locate_player()
	_setup_nameplate_height()


## Bypasses old procedural representation compiling
func _build_visual_representation() -> void:
	pass


## Decoupled height calculation sourcing boundaries directly from the scene setup
func _setup_nameplate_height() -> void:
	var col := get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col) and col.shape is CylinderShape3D:
		var cylinder := col.shape as CylinderShape3D
		_collision_height = cylinder.height
		
	_setup_nameplate()
	
	# Aligns nameplate correctly above the visual model
	if is_instance_valid(_nameplate):
		_nameplate.position.y = _collision_height + 0.35


# ==============================================================================
# CIRCULAR SHIELD: Return int directly (0 = TERRESTRIAL, 1 = AMPHIBIOUS, 2 = AQUATIC)
# This perfectly complies with LSP overrides and stops circular import compilation deadlocks.
# ==============================================================================
func _get_habitat() -> int:
	return 2 # Equivalent to MobRegistry.Habitat.AQUATIC


func _has_ui_decorations() -> bool:
	return true # Explicitly true to ensure warning red nameplate is drawn!


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


## Hostiles do not panic when hit
func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


## Drops 1x Sand Block on death
func _drop_loot(inv: IInventory) -> void:
	inv.add_item(7, 1)


# ==============================================================================
# PROCEDURAL SWIMMING ENGINE (Sinusoidal Tail-Wagging)
# ==============================================================================
func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	if is_instance_valid(_model_node):
		_animation_time += delta
		
		var flat_velocity := Vector2(velocity.x, velocity.z)
		var is_moving := flat_velocity.length_squared() > 0.1
		
		if is_moving:
			# Fast tail wagging when swimming rapidly (Yaw oscillation on Z-axis offset)
			var swim_speed := flat_velocity.length() * 2.5
			_model_node.rotation.y = deg_to_rad(-90.0) + sin(_animation_time * swim_speed) * 0.22
			_model_node.rotation.z = cos(_animation_time * swim_speed * 0.5) * 0.08 
		else:
			# Calm, idle ocean current swaying
			_model_node.rotation.y = lerp(_model_node.rotation.y, deg_to_rad(-90.0), delta * 5.0)
			_model_node.rotation.z = sin(_animation_time * 1.5) * 0.03


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
	
	# Apply the physical absolute habitat barrier boundary check before moving!
	_apply_absolute_boundary_forcefield(delta)
	
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
		
		var visuals_node := get_node_or_null("NPCVisualComponent/Visuals") as Node3D
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
