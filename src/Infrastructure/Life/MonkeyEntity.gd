# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: MonkeyEntity
# Description: Physical character controller for the acrobatic Tropical Monkey.
#              Delegates all leaf clambering, branches perching, and backflip 
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
	
	# TANGENT SHIELD FIX: Strip materials of tangent-requiring shaders to avoid C++ warnings
	var model_node := get_node_or_null("Visuals/BodyBobJoint/monkey") as Node3D
	if is_instance_valid(model_node):
		_register_glb_materials(model_node)
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Monkey acrobatic AI strategy dynamically on ready,
	# completely overriding the default generic wildlife behavior assigned by Bootstrap.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = MonkeyAIBehavior.new()


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
