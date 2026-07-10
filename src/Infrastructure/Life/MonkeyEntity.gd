# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: MonkeyEntity
# Description: Physical character controller for the acrobatic Tropical Monkey.
#              Delegates all leaf clambering, branches perching, and backflip 
#              cooldowns to the decoupled MonkeyAIBehavior strategy, managing
#              procedural visual mesh rolls and spatial audio cues.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, local audio vocal timers, and programmatic 
#   mesh rolls, keeping the shared Domain clambering strategy pristine.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, relying 100% on the base physics loop for standard translations
#   without compiling conflicts.
# - Dependency Inversion Principle (DIP): Injects the MonkeyAIBehavior strategy 
#   during ready state initialization and utilizes our OCP AudioService locator.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MonkeyEntity.gd
# ==============================================================================
class_name MonkeyEntity
extends PassiveEntity

# --- TACTICAL AUDIO COOLDOWN TIMERS (SRP / OCP Compliant) ---
# Throttled interval preventing the audio from overlapping
const COOLDOWN_CHAT_MIN_SEC: float = 15.0
const COOLDOWN_CHAT_MAX_SEC: float = 25.0

# Start with a random initial offset so they don't all yell at spawn
var _chat_timer: float = randf_range(5.0, 15.0)


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
# TACTICAL AUDIO & ACROBATIC PRESENTATION
# ==============================================================================

## Visual/Audio Monkey Chatter: Plays the designated ambient spatial monkey sound
func _play_monkey_chatter() -> void:
	# Plays the dynamic ambient monkey sound using our refactored OCP service locator.
	# The AudioService automatically handles max spatial distance (20m) and 
	# auto-frees the player when finished to guarantee no memory leaks!
	AudioService.play_sfx_static("monkey_chatter", global_position)


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
		
	# Play high-pitched meow-squeak sound statically as a physical exertion effort
	AudioService.play_sfx_static("npc_chat", global_position)


func _process(delta: float) -> void:
	# REMOVED: super(delta) because PassiveEntity does not implement _process()
	if domain_entity.is_dead:
		return
		
	# ==========================================================================
	# AMBIENT CHATTER TIMER (OCP / SRP Compliant)
	# Processed locally in the presenter to decouple audio from domain climb nodes
	# ==========================================================================
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5: # TASK_PANIC = 5
		is_panicking = true
		
	if not is_panicking:
		_chat_timer -= delta
		if _chat_timer <= 0.0:
			_chat_timer = randf_range(COOLDOWN_CHAT_MIN_SEC, COOLDOWN_CHAT_MAX_SEC)
			_play_monkey_chatter()
