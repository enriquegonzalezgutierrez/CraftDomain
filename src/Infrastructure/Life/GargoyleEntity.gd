# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: GargoyleEntity
# Description: Physical character controller for the hostile nocturnal Gargoyle.
#              It delegates all state machine decisions, chasing vectors, and 
#              attack cooldowns to the decoupled GargoyleAIBehavior strategy, 
#              focusing strictly on physical translations and visual flight animations.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical movement, 
#   gravity damping during active flight, and visual billboarding.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contracts, utilizing its parent signal connections polymorphically.
# - Dependency Inversion Principle (DIP): Receives its behavior strategy via 
#   dependency injection inside _ready(), purging direct inline state machines.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GargoyleEntity.gd
# ==============================================================================
class_name GargoyleEntity
extends PassiveEntity

# Sibling node references
var player: CharacterBody3D

# Visual animation trackers
var _animation_time: float = 0.0
var _model_node: Node3D

# Physical flight configurations (decoupled from decisions)
const SPEED: float = 3.0


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Gargoyles spawn with 6 Hearts of health (high stone defense: 12 HP)
	super(spawn_pos, 12)
	name = "Entity_GARGOYLE"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the hostile group for O(1) targeting
	add_to_group("hostiles")
	
	# Cache component references pre-configured in the scene
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/gargoyle") as Node3D
	
	_locate_player()
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Gargoyle nocturnal AI strategy dynamically on ready,
	# completely overriding the default zombie behavior assigned by Bootstrap.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = GargoyleAIBehavior.new()


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
# ==============================================================================
func _get_nameplate_color() -> Color:
	return Color(1.0, 0.15, 0.15) # Red warning nameplate


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
## Note: Invoked via reflective calls by the GargoyleAIBehavior strategy
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


## Tactical Action bite: Inflicts damage and applies diagonal knockback
## Note: Invoked via reflective calls by the GargoyleAIBehavior strategy
func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(dir.x * 5.5, 0.25, dir.z * 5.5)
		if player.has_method("take_damage"):
			player.call("take_damage", 1, knockback)


# ==============================================================================
# MAIN GEOMETRIC PRESENTATION & FLIGHT BOBBING OSCILLATION
# ==============================================================================
func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	if is_instance_valid(_model_node):
		_animation_time += delta
		
		# Read nocturnal state from metadata safely (DIP)
		var state: int = 0
		if has_meta(GargoyleAIBehavior.META_STATE):
			state = get_meta(GargoyleAIBehavior.META_STATE) as int
		
		if state == 1: # AWAKE / FLYING
			var flat_velocity := Vector2(velocity.x, velocity.z)
			var is_moving := flat_velocity.length_squared() > 0.1
			
			# Smooth hover bobbing oscillation
			var hover_bob := sin(_animation_time * 5.0) * 0.25
			_model_node.position.y = 2.5 + hover_bob
			
			if is_moving:
				_model_node.rotation.z = sin(_animation_time * 14.0) * 0.18
				_model_node.rotation.x = deg_to_rad(12.0) # Pitch forward
			else:
				_model_node.rotation.z = sin(_animation_time * 2.0) * 0.05
				_model_node.rotation.x = 0.0
		else: # STONE STATUE (Sits flat on floor)
			_model_node.position.y = lerp(_model_node.position.y, 0.8982, delta * 5.0)
			_model_node.rotation = lerp(_model_node.rotation, Vector3(0.0, deg_to_rad(90.0), 0.0), delta * 5.0)
			
		# Synchronize Label3D Nameplate's height dynamically with flight bobbing sways!
		if is_instance_valid(_nameplate):
			_nameplate.position.y = _model_node.position.y + 1.05


# ==============================================================================
# UN-THROTTLED PHYSICS ENGINE (GRAVITY AND STEP- avoidance)
# ==============================================================================
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return

	# Read state from metadata to calculate physical gravity vectors safely
	var state: int = 0
	if has_meta(GargoyleAIBehavior.META_STATE):
		state = get_meta(GargoyleAIBehavior.META_STATE) as int

	if state == 0: # STONE (Acts as a heavy brick, falls to ground)
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = -0.1
	else: # AWAKE (Active flight neutral Y damping)
		velocity.y = move_toward(velocity.y, 0.0, SPEED * delta)

	# Execute un-throttled physics translation and step-up checks
	if is_instance_valid(ai_component):
		ai_component.process_ai(delta)

	move_and_slide()
