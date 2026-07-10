# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: ChickenEntity
# Description: Physical character controller for the passive Prairie Chicken.
#              Exclusively manages walking translations, simple avian sways, 
#              and dynamic, scale-aware nameplate floating.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates exclusively physical 
#   movement loops, flight bobs, and life-signals, delegating visual and 
#   collision parameters to the Godot Editor (.tscn).
# - Liskov Substitution Principle (LSP): Subclasses PassiveEntity and satisfies 
#   the base contracts without code-based instantiation overrides.
# - Dependency Inversion Principle (DIP): Relies on abstract interfaces 
#   (IInventory) to process loot drops.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/ChickenEntity.gd
# ==============================================================================
class_name ChickenEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Chickens spawn with 1 Heart of health (2 HP, fragile)
	super(spawn_pos, 2) 
	name = "Entity_CHICKEN"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()


## Bypasses old procedural representation compiling
func _build_visual_representation() -> void:
	pass # Visual model is instanced directly in the .tscn scene file


func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	inv.add_item(16, 1)


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _is_avian() -> bool:
	return true # Triggers slight procedural walking tilts inside base class


func _can_socialize() -> bool:
	return true
