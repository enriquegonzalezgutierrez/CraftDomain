# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Wildlife)
# Class: ChickenEntity
# Description: Physical character controller for the passive Prairie Chicken.
#              Delegates its visual clay-voxel representation and physical 
#              translations completely to the Godot Editor (.tscn).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates exclusively physical 
#   movement loops, flight bobs, and life-signals, delegating visual and 
#   collision parameters to the Godot Editor (.tscn).
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
# ==============================================================================
class_name ChickenEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 2)
	entity_habitat = 0 # Terrestrial
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


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _get_entity_name_key() -> String:
	return "NPC_NAME_CHICKEN"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Friendly/Passive Green


func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken (acting as raw chicken proxy)
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return true # Triggers slight procedural walking tilts inside base class


func _can_socialize() -> bool:
	return true
