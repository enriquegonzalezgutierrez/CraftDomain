# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: FoxEntity
# Description: Physical character controller for the forest predator Fox.
#              Delegates leaves scans, crawling crouches, and pounce leaps
#              to the decoupled FoxAIBehavior strategy, managing visual flattening
#              offsets and strike damage upon landings.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, and dynamic crouching mesh scales.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, preserving base damage hooks while enforcing customized reflexes.
# - Dependency Inversion Principle (DIP): Injects the FoxAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/FoxEntity.gd
# ==============================================================================
class_name FoxEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Foxes spawn with 2 Hearts of health (4 HP)
	super(spawn_pos, 4)
	name = "Entity_FOX"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# TANGENT SHIELD FIX: Strip materials of tangent-requiring shaders to avoid C++ warnings
	var model_node := get_node_or_null("Visuals/BodyBobJoint/fox") as Node3D
	if is_instance_valid(model_node):
		_register_glb_materials(model_node)
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Fox predator AI strategy dynamically on ready,
	# completely overriding the default generic wildlife behavior assigned by Bootstrap.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = FoxAIBehavior.new()


## Recursively duplicates and sanitizes materials across ALL mesh surfaces (Tangent Shield)
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		# Multi-Surface Sweep: Sanitize every material index on the mesh
		for i: int in range(node.mesh.get_surface_count()):
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

func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


## Reactive callback triggered when the Domain Entity registers a successful hit.
func _on_domain_entity_took_damage(amount: int) -> void:
	# 1. Restore the base class signal chains (Alert network and Panic logic)
	super(amount)
	
	# 2. Apply custom quick startle jump velocity
	velocity.y = JUMP_VELOCITY


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Meat rations (ID 16)
	inv.add_item(16, 1)


# ==============================================================================
# TACTICAL PRESENTATION & SNEAKING CROUCH & STRIKES
# ==============================================================================

## Visual Crouch: Smoothly scales model height down to simulate stealth prowling
## Note: Invoked via reflective calls by the FoxAIBehavior strategy
func _set_crouch_height(is_crouched: bool) -> void:
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.visual_root):
		var target_scale_y := 0.65 if is_crouched else 1.0
		var target_pos_y := 0.01 if is_crouched else 0.02
		
		# Smooth visual interpolation
		visual_component.visual_root.scale.y = lerp(visual_component.visual_root.scale.y, target_scale_y, 0.12)
		visual_component.visual_root.position.y = lerp(visual_component.visual_root.position.y, target_pos_y, 0.12)


## Pounce Strike: Emits pounce bark and inflicts damage (1 Heart / 2 HP) on prey
## Note: Invoked via reflective calls by the FoxAIBehavior strategy
func _execute_pounce_strike(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
		
	# Play high-pitched canine alert statically (Service Locator)
	AudioService.play_sfx_static("npc_chat", global_position)
	
	# Execute damage strike upon landing
	if target.has_method("take_damage"):
		var direction_vec: Vector3 = (target.global_position - global_position).normalized()
		var pounce_knockback: Vector3 = direction_vec * 4.2 + Vector3(0.0, 1.8, 0.0)
		target.call("take_damage", 2, pounce_knockback, self) # Inflicts 2 HP (1 Heart)
