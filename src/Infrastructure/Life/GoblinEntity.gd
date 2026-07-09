# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: GoblinEntity
# Description: Physical character controller for the hostile skirmisher Goblin.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, and entity nameplate styling.
# BUG FIX:
# - Added `_register_glb_materials()` to strip tangent and normal-map rendering
#   requirements from the GLB mesh, completely suppressing the Godot C++ shader 
#   warning spam in the console.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GoblinEntity.gd
# ==============================================================================
class_name GoblinEntity
extends PassiveEntity

# Sibling node references
var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Goblins spawn with 2 Hearts of health (4 HP, fragile skirmisher)
	super(spawn_pos, 4)
	name = "Entity_GOBLIN"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the hostile group for O(1) targeting sweeps
	add_to_group("hostiles")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# TANGENT SHIELD FIX: Strip materials of tangent-requiring shaders to avoid C++ warnings
	var model_node := get_node_or_null("Visuals/BodyBobJoint/goblin") as Node3D
	if is_instance_valid(model_node):
		_register_glb_materials(model_node)
	
	_locate_player()
	_setup_nameplate_height()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = GoblinAIBehavior.new()


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


func _get_nameplate_color() -> Color:
	return Color(1.0, 0.15, 0.15)


func _get_habitat() -> int:
	return 0 # TERRESTRIAL


func _has_ui_decorations() -> bool:
	return true


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(1, 1)


func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(dir.x * 5.5, 0.25, dir.z * 5.5)
		if player.has_method("take_damage"):
			player.call("take_damage", 1, knockback)
