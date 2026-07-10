# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: GolemEntity
# Description: Physical character controller for the village protector Iron Golem.
#              Delegates all pro-active scans, chasing speed multipliers, 
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
	
	# TANGENT SHIELD FIX: Strip materials of tangent-requiring shaders to avoid C++ warnings
	var model_node := get_node_or_null("Visuals/BodyBobJoint/golem") as Node3D
	if is_instance_valid(model_node):
		_register_glb_materials(model_node)
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Golem protective AI strategy dynamically on ready,
	# completely overriding the default generic guard behavior.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = GolemAIBehavior.new()


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
	
	# Ballistical launch vector pointing 9.5 meters up!
	var throw_force: Vector3 = target_dir * 3.5 + Vector3(0.0, 9.5, 0.0)
	
	if target.has_method("take_damage"):
		target.call("take_damage", 2, throw_force, self)
