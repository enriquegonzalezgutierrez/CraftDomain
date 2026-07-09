# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: MonkeyEntity
# Description: Physical character controller for the acrobatic Tropical Monkey.
#              It delegates all leaf clambering, branches perching, and backflips
#              cooldowns to the decoupled MonkeyAIBehavior strategy, managing
#              procedural visual mesh rolls and squeak audio cues.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, and programmatic backflip mesh rolls.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, relying 100% on the base physics loop for standard translations.
# - Dependency Inversion Principle (DIP): Injects the MonkeyAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MonkeyEntity.gd
# ==============================================================================
class_name MonkeyEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Monkeys spawn with 3 Hearts of health (6 HP)
	super(spawn_pos, 6)
	name = "Entity_MONKEY"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Monkey acrobatic AI strategy dynamically on ready,
	# completely overriding the default generic wildlife behavior assigned by Bootstrap.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = MonkeyAIBehavior.new()


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

## Returns int directly (0 = TERRESTRIAL, 1 = AMPHIBIOUS, 2 = AQUATIC)
func _get_habitat() -> int:
	return 0 # Equivalent to MobRegistry.Habitat.TERRESTRIAL


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Fried Chicken (acting as raw monkey-meat proxy)
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


# ==============================================================================
# TACTICAL ACROBATIC JUMPING & TWIRL EFFECTS
# ==============================================================================

## Visual Backflip: Propels vertically and rotates 360 degrees on X-axis (Pitch roll)
## Note: Invoked via reflective calls by the MonkeyAIBehavior strategy
func _play_backflip_effect() -> void:
	# Propel physically upward with extra spring force
	velocity.y = JUMP_VELOCITY * 1.3
	
	# Symmetrical visual twirl rotation loop using Godot's Tween engine
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.visual_root):
		var flip_tween := create_tween()
		
		# Rotate 360 degrees (TAU radians) along the Pitch (X-axis)
		var start_rot_x: float = visual_component.visual_root.rotation.x
		flip_tween.tween_property(visual_component.visual_root, "rotation:x", start_rot_x - TAU, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		flip_tween.chain().tween_callback(func() -> void:
			if is_instance_valid(visual_component) and is_instance_valid(visual_component.visual_root):
				visual_component.visual_root.rotation.x = start_rot_x # Reset rotation exactly
		)
		
	# Play high-pitched meow-squeak sound statically (Service Locator)
	AudioService.play_sfx_static("npc_chat", global_position)
