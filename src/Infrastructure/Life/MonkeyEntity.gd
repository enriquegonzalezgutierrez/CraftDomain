# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Description: Physics controller for the passive Tropical Monkey.
#              STABILIZATION: Removed redundant signal connections already handled.
# ==============================================================================
class_name MonkeyEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 6)
	name = "Entity_MONKEY"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_nameplate_height()


func _build_visual_representation() -> void:
	pass


func _setup_nameplate_height() -> void:
	var col := get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col) and col.shape is CylinderShape3D:
		var cylinder := col.shape as CylinderShape3D
		_collision_height = cylinder.height
		
	_setup_nameplate()
	if is_instance_valid(_nameplate):
		_nameplate.position.y = _collision_height + 0.35


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return false

func _can_socialize() -> bool:
	return true
