# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Description: Physics controller for the hostile skirmisher Goblin, designed to
#              be attached to a '.tscn' scene file.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively rapid
#                skirmishing AI, alarm networking, and escape routing, delegating
#                visual and collision parameters to the Godot Editor.
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity,
#                swapping groups cleanly without code-based instantiation.
#              CIRCULAR DEPENDENCY SHIELD:
#              - Changed '_get_habitat()' return signature to 'int' to safely break
#                the GDScript compilation lock with MobRegistry class name.
#              STABILIZATION:
#              - Removed redundant signal connections already handled in parent class.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GoblinEntity.gd
# ==============================================================================
class_name GoblinEntity
extends PassiveEntity

# Combat configurations (Fast, fragile skirmisher)
const SPEED: float = 3.5
const CHASE_RANGE: float = 16.0
const ATTACK_RANGE: float = 1.2
const ATTACK_COOLDOWN_INTERVAL: float = 1.2

# Sibling node references
var player: CharacterBody3D

# AI wandering/chasing state variables
var _wander_timer: float = 0.0
var _wander_direction: Vector3 = Vector3.ZERO
var _is_wandering: bool = false
var _attack_cooldown_timer: float = 0.0
var _stuck_timer: float = 0.0


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Goblins spawn with 2 Hearts of health (4 HP, fragile)
	super(spawn_pos, 4)
	name = "Entity_GOBLIN"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the hostile group for O(1) targeting
	add_to_group("hostiles")
	
	# Cache component references pre-configured in the scene
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
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
	return 0 # Equivalent to MobRegistry.Habitat.TERRESTRIAL


func _has_ui_decorations() -> bool:
	return true # Explicitly true to ensure warning red nameplate is drawn!


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


## Hostiles do not panic when hit, they charge forward!
func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


## Drops 1x Stone Block on death
func _drop_loot(inv: IInventory) -> void:
	inv.add_item(1, 1)


# ==============================================================================
# MAIN HOSTILE PHYSICS & AI CALCULATIONS
# ==============================================================================
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

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
		if global_position.distance_to(player.global_position) < CHASE_RANGE:
			_is_wandering = true
			_wander_direction = (player.global_position - global_position).normalized()
			_wander_direction.y = 0
			is_player_trackable = true
			
			if global_position.distance_to(player.global_position) <= ATTACK_RANGE:
				if _attack_cooldown_timer <= 0.0:
					_bite_player()
					_attack_cooldown_timer = ATTACK_COOLDOWN_INTERVAL
					# Trigger local visual attack if strategy is setup
					if is_instance_valid(visual_representation):
						visual_representation.trigger_attack_visuals()
				
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
		
		if is_on_wall():
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
				
			_stuck_timer += delta
			var patience := 1.0 if is_player_trackable else 0.4 
			
			if _stuck_timer > patience:
				_stuck_timer = 0.0
				if not is_player_trackable:
					var wall_normal := get_wall_normal()
					var flat_normal := Vector3(wall_normal.x, 0, wall_normal.z).normalized()
					if flat_normal != Vector3.ZERO:
						_wander_direction = _wander_direction.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.3, 0.3)).normalized()
					else:
						var angle := randf() * TAU
						_wander_direction = Vector3(cos(angle), 0, sin(angle))
		else:
			_stuck_timer = 0.0
			
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)


func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(dir.x * 5.5, 0.25, dir.z * 5.5)
		if player.has_method("take_damage"):
			player.call("take_damage", 1, knockback)
