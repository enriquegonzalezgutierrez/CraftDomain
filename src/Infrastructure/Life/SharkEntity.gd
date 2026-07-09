# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: SharkEntity
# Description: Physical character controller for the hostile Great White Shark.
#              It delegates all coordinate scent tracking, player chase paths, 
#              and surface leap attacks to the decoupled SharkAIBehavior strategy,
#              focusing strictly on swimming tail-wag oscillations and damage.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, and procedural mesh tail-wag animations.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, utilizing its parent physics process and signals.
# - Dependency Inversion Principle (DIP): Injects the SharkAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/SharkEntity.gd
# ==============================================================================
class_name SharkEntity
extends PassiveEntity

# Sibling node references
var player: CharacterBody3D

# Dynamic cached reference to visual model
var _model_node: Node3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Sharks spawn with 4 Hearts of health (8 HP)
	super(spawn_pos, 8)
	name = "Entity_SHARK"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the hostile group for target lookups
	add_to_group("hostiles")
	
	# Cache component references pre-configured in the scene
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/shark") as Node3D
	
	_locate_player()
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Shark aquatic predator AI strategy dynamically on ready,
	# completely overriding the default generic wildlife behavior assigned by Bootstrap.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = SharkAIBehavior.new()


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
	return 2 # Equivalent to MobRegistry.Habitat.AQUATIC


func _has_ui_decorations() -> bool:
	return true


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


## Tactical Action bite: Inflicts heavy damage (1.5 Hearts / 3 HP) and applies knockback
## Note: Invoked via reflective calls by the SharkAIBehavior strategy
func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		# High vertical-diagonal propulsion to push the player away in water
		var knockback := Vector3(dir.x * 6.5, 2.5, dir.z * 6.5)
		if player.has_method("take_damage"):
			player.call("take_damage", 3, knockback)


# ==============================================================================
# MAIN PHYSICS LOOP & PROCEDURAL TAIL-WAG OSCILLATION
# ==============================================================================
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	# Process procedural tail wave animations before standard translations
	_process_procedural_swimming(delta)
	super(delta)


func _process_procedural_swimming(delta: float) -> void:
	if is_instance_valid(_model_node):
		var anim_time: float = Time.get_ticks_msec() / 1000.0
		var flat_velocity := Vector2(velocity.x, velocity.z)
		var is_moving := flat_velocity.length_squared() > 0.1
		
		if is_moving:
			# Tail-wagging frequency scales dynamically with active movement speed
			var swim_speed := flat_velocity.length() * 2.5
			_model_node.rotation.y = deg_to_rad(-90.0) + sin(anim_time * swim_speed) * 0.22
			_model_node.rotation.z = cos(anim_time * swim_speed * 0.5) * 0.08 
		else:
			# Slow resting ocean current sways
			_model_node.rotation.y = lerp(_model_node.rotation.y, deg_to_rad(-90.0), delta * 5.0)
			_model_node.rotation.z = sin(anim_time * 1.5) * 0.03
