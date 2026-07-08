# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Description: Physics controller for the passive Chicken, designed to be attached
#              to a '.tscn' scene file.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively physical
#                movement loops, flight bobs, and life-signals, delegating visual
#                and collision parameters to the Godot Editor.
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity
#                and satisfies the base contracts without code-based instantiation.
#              STABILIZATION:
#              - Removed redundant signal connections already handled in parent class.
# ==============================================================================
class_name ChickenEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Chickens spawn with 1 Heart of health (2 HP)
	super(spawn_pos, 2) 
	name = "Entity_CHICKEN"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Fetch nameplate configurations if available
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


func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return true


func _can_socialize() -> bool:
	return true
