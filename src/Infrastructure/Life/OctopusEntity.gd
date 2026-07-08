# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Class: OctopusEntity
# Description: Physical character controller representing a passive aquatic Octopus.
#              Schedules animation rigging, handles water bounds, and registers its 
#              specialized FaunaAIBehavior strategy dynamically on ready.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively physical body 
#   water translations and target visual attachments, delegating movement and 
#   swim logic to the injected FaunaAIBehavior.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   parent class, utilizing its base physics processes and gravity vectors transparently.
# - Dependency Inversion Principle (DIP): Receives its behavioral decision tree 
#   via dynamic strategy injection on startup.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name OctopusEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Octopus spawns with 3 Hearts of health (6 HP)
	super(spawn_pos, 6)
	name = "Entity_OCTOPUS"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Fetch nameplate configurations if available
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Programmatically instantiates NPCAIComponent if missing from old scenes
	# ==========================================================================
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	if not is_instance_valid(ai_component):
		ai_component = NPCAIComponent.new()
		add_child(ai_component)
		
	if is_instance_valid(ai_component):
		ai_component.active_behavior = FaunaAIBehavior.new()


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


func _get_habitat() -> int:
	return 2 # AQUATIC


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Sand Block
	inv.add_item(7, 1)


func _is_avian() -> bool:
	return true # Activates slight procedural swim/crawl tilts


func _can_socialize() -> bool:
	return true
