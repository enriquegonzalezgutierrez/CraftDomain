# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Class: GargoyleEntity
# Description: Physical character controller representing a hostile nocturnal Gargoyle.
#              Schedules animation sways, handles day/night state transforms, 
#              and overrides its nameplate warning color polimorphically.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively active flight and 
#   statue transformations, delegating nameplate styling to the virtual base contract.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   parent class, utilizing its base physics and save loops transparently.
# - Dependency Inversion Principle (DIP): Relies on the base class nameplate 
#   compiler instead of manual script overrides.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name GargoyleEntity
extends PassiveEntity

enum State { STONE, AWAKE }

# Sibling node references
var player: CharacterBody3D

# AI and state trackers
var current_state: State = State.STONE
var _wander_timer: float = 0.0
var _wander_direction: Vector3 = Vector3.ZERO
var _is_wandering: bool = false
var _attack_cooldown_timer: float = 0.0
var _animation_time: float = 0.0

# Dynamic cached reference to visual model
var _model_node: Node3D

# Combat configurations
const SPEED: float = 3.0
const CHASE_RANGE_SQ: float = 256.0 # 16m squared
const ATTACK_RANGE_SQ: float = 3.0
const ATTACK_COOLDOWN_INTERVAL: float = 1.5


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Gargoyles spawn with 6 Hearts of health (high stone defense: 12 HP)
	super(spawn_pos, 12)
	name = "Entity_GARGOYLE"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the hostile group for O(1) targeting
	add_to_group("hostiles")
	
	# Bind pure Domain Model signals
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)
	
	# Cache component references pre-configured in the scene
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/gargoyle") as Node3D
	
	_locate_player()
	_setup_nameplate_height()
	
	# Symmetrical initial check to set the gargoyle to stone if spawned during daytime
	var is_night := CelestialService.is_night_time_static()
	_update_nocturnal_state(is_night)


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
	
	if is_instance_valid(_nameplate):
		_nameplate.position.y = _collision_height + 0.35


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# Overrides nameplate color return value to warning crimson red
# ==============================================================================
func _get_nameplate_color() -> Color:
	return Color(1.0, 0.15, 0.15)


func _get_habitat() -> int:
	return 0 # TERRESTRIAL


func _has_ui_decorations() -> bool:
	return true


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


## Hostiles do not panic when hit
func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


## Drops 1x Stone Block on death
func _drop_loot(inv: IInventory) -> void:
	inv.add_item(1, 1)


## Symmetrical transition updating stone shaders/emission visual overlays
func _set_gargoyle_stone_appearance(is_stone: bool) -> void:
	if is_instance_valid(_model_node):
		_traverse_and_apply_stone_appearance(_model_node, is_stone)


func _traverse_and_apply_stone_appearance(node: Node, is_stone: bool) -> void:
	if node is MeshInstance3D:
		var mat := node.material_override as BaseMaterial3D
		if is_instance_valid(mat):
			if is_stone:
				mat.albedo_color = Color(0.48, 0.48, 0.50) # Solid grey statue
				mat.roughness = 1.0
			else:
				mat.albedo_color = Color(1.0, 1.0, 1.0) # Restored textures
				mat.roughness = 0.5
				
	for child in node.get_children():
		_traverse_and_apply_stone_appearance(child, is_stone)


# ==============================================================================
# MAIN HOSTILE PHYSICS & AI CALCULATIONS
# ==============================================================================
func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	if is_instance_valid(_model_node):
		_animation_time += delta
		
		if current_state == State.AWAKE:
			var flat_velocity := Vector2(velocity.x, velocity.z)
			var is_moving := flat_velocity.length_squared() > 0.1
			
			var hover_bob := sin(_animation_time * 5.0) * 0.25
			_model_node.position.y = 2.5 + hover_bob
			
			if is_moving:
				_model_node.rotation.z = sin(_animation_time * 14.0) * 0.18
				_model_node.rotation.x = deg_to_rad(12.0) # Pitch forward
			else:
				_model_node.rotation.z = sin(_animation_time * 2.0) * 0.05
				_model_node.rotation.x = 0.0
		else:
			_model_node.position.y = lerp(_model_node.position.y, 0.8982, delta * 5.0)
			_model_node.rotation = lerp(_model_node.rotation, Vector3(0.0, deg_to_rad(90.0), 0.0), delta * 5.0)
			
		# Synchronize Nameplate's height dynamically with flight bobbing sways!
		if is_instance_valid(_nameplate):
			_nameplate.position.y = _model_node.position.y + 1.05


func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return

	# Query Celestial clock statically (DIP compliant)
	var is_night := CelestialService.is_night_time_static()
	_update_nocturnal_state(is_night)

	if current_state == State.STONE:
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = -0.1
		velocity.x = move_toward(velocity.x, 0, SPEED * delta)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta)
	else:
		velocity.y = move_toward(velocity.y, 0, SPEED * delta)
		if _attack_cooldown_timer > 0.0:
			_attack_cooldown_timer -= delta
			
		if not is_instance_valid(player):
			_locate_player()
			
		_process_ai_intelligence(delta)

	move_and_slide()


func _update_nocturnal_state(is_night: bool) -> void:
	if is_night and current_state == State.STONE:
		current_state = State.AWAKE
		print("[Gargoyle] GOTHIC SENTINEL AWAKENS!")
		_set_gargoyle_stone_appearance(false)
				
	elif not is_night and current_state == State.AWAKE:
		current_state = State.STONE
		print("[Gargoyle] GOTHIC SENTINEL TURNS TO STONE.")
		_set_gargoyle_stone_appearance(true)


func _process_ai_intelligence(_delta: float) -> void:
	var _wander_direction_tmp: Vector3 = Vector3.ZERO
	_wander_timer -= _delta
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
