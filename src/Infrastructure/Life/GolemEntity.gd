# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: GolemEntity
# Description: Physical character controller for the village protector Iron Golem.
#              It delegates all pro-active scans, chasing speed multipliers, 
#              and combat schedules to the decoupled GolemAIBehavior strategy,
#              focusing on physical translations, nameplates, and mass launcher slams.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical mass 
#   translations, heavy box cylinder colliders, and ballistical strikes.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, relying 100% on the base physics loop for standard translations.
# - Dependency Inversion Principle (DIP): Injects the GolemAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GolemEntity.gd
# ==============================================================================
class_name GolemEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Heavy colossus initialized with 15 Hearts of health (30 HP)
	super(spawn_pos, 30)
	name = "Entity_GOLEM"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for defender lookups
	add_to_group("passives")
	
	# Register in the shared alert network
	var alert_net := AlertNetworkService.instance
	if is_instance_valid(alert_net):
		alert_net.register_defender(self)
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Fetch nameplate configurations if available
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Golem protective AI strategy dynamically on ready,
	# completely overriding the default generic guard behavior.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = GolemAIBehavior.new()


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
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

## Returns int directly (0 = TERRESTRIAL, 1 = AMPHIBIOUS, 2 = AQUATIC)
func _get_habitat() -> int:
	return 0 # Equivalent to MobRegistry.Habitat.TERRESTRIAL


func _has_ui_decorations() -> bool:
	return true


func _can_socialize() -> bool:
	# Golems are silent defenders, socializing is disabled
	return false


func _is_avian() -> bool:
	return false


# ==============================================================================
# HEAVY MILITARY BALLISTICAL COMBAT SYSTEM
# ==============================================================================

## Symmetrical Heavy Strike: Deals 2 Hearts (4 HP) of damage and throws targets 9.5m high!
## Note: Invoked via reflective calls by GolemAIBehavior strategy
func _execute_heavy_combat_strike(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
		
	var target_dir := (target.global_position - global_position).normalized()
	target_dir.y = 0.0
	
	# Balistical launch vector pointing 9.5 meters up!
	var throw_force := target_dir * 3.5 + Vector3(0.0, 9.5, 0.0)
	
	if target.has_method("take_damage"):
		target.call("take_damage", 2, throw_force, self)
