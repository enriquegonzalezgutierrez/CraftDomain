# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: CowEntity
# Description: Physical character controller for the passive Clay Cow.
#              Delegates its visual voxel/clay representation and physical 
#              translations completely to the Godot Editor (.tscn).
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Coordinates exclusively physical 
#   passive movement, panic bounces, and signal-bound loot drops.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, utilizing inherited dynamic height solvers.
# - Dependency Inversion Principle (DIP): Relies on abstract interfaces 
#   (IInventory) to process loot drops.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/CowEntity.gd
# ==============================================================================
class_name CowEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Cows spawn with 3 Hearts of health (6 HP)
	super(spawn_pos, 6)
	name = "Entity_COW"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# TANGENT SHIELD FIX: Strip materials of tangent-requiring shaders to avoid C++ warnings
	var model_node := get_node_or_null("Visuals/BodyBobJoint/cow") as Node3D
	if is_instance_valid(model_node):
		_register_glb_materials(model_node)
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()


## Recursively duplicates and sanitizes materials across ALL mesh surfaces (Tangent Shield)
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		# Multi-Surface Sweep: Sanitize every material index on the mesh
		for i: int in range(node.mesh.get_surface_count()):
			# FIXED: Explicitly typed variable declaration to satisfy strict static compiler
			var mat: Material = node.get_active_material(i)
			if mat == null:
				mat = node.mesh.surface_get_material(i)
				
			if mat is BaseMaterial3D:
				var new_mat := mat.duplicate() as BaseMaterial3D
				# TANGENT WARNING SHIELD
				new_mat.normal_enabled = false
				new_mat.anisotropy_enabled = false
				new_mat.clearcoat_enabled = false
				new_mat.heightmap_enabled = false
				node.set_surface_override_material(i, new_mat)
			
	for child: Node in node.get_children():
		_register_glb_materials(child)


## Bypasses old procedural representation compiling
func _build_visual_representation() -> void:
	pass # Visual model is instanced directly in the .tscn scene file


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _get_habitat() -> int:
	return 0 # Equivalent to MobRegistry.Habitat.TERRESTRIAL


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Fertile Soil (ID 2) and 1x raw cow meat (Fried Chicken proxy ID 16)
	inv.add_item(2, 1)
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true
