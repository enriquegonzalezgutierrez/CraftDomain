# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Description: Physics controller for the passive Sheep. Delegating its visual
#              clay-voxel representation and collision properties to its scene.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Handles exclusively physical
#   passive movement, panic bounces, and signal-bound loot drops.
# BUG FIX:
# - Added `_register_glb_materials()` to strip tangent and normal-map rendering
#   requirements from the GLB mesh, completely suppressing the Godot C++ shader 
#   warning spam in the console.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/SheepEntity.gd
# ==============================================================================
class_name SheepEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Sheep spawn with 1 Heart of health (2 HP)
	super(spawn_pos, 2)
	name = "Entity_SHEEP"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# TANGENT SHIELD FIX: Strip materials of tangent-requiring shaders to avoid C++ warnings
	var model_node := get_node_or_null("Visuals/BodyBobJoint/sheep") as Node3D
	if is_instance_valid(model_node):
		_register_glb_materials(model_node)
	
	_setup_nameplate_height()


## Recursively duplicates materials to prevent material-sharing leaks and tangent errors
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: Material = node.get_active_material(0)
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0)
			
		if mat is BaseMaterial3D:
			var new_mat := mat.duplicate() as BaseMaterial3D
			# TANGENT WARNING SHIELD
			new_mat.normal_enabled = false
			new_mat.anisotropy_enabled = false
			new_mat.clearcoat_enabled = false
			new_mat.heightmap_enabled = false
			node.material_override = new_mat
			
	for child: Node in node.get_children():
		_register_glb_materials(child)


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


func _get_habitat() -> int:
	return 0 # TERRESTRIAL


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(5, 1)
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true
