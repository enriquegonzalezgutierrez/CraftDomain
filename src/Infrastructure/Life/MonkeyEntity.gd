# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Wildlife)
# Class: MonkeyEntity
# Description: Physical character controller for the acrobatic Tropical Monkey.
#              Delegates all leaf clambering, branches perching, and backflip 
#              cooldowns to the decoupled MonkeyAIBehavior strategy, managing
#              procedural visual mesh rolls.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, local audio vocal timers, and programmatic 
#   mesh rolls, keeping the shared Domain clambering strategy pristine.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
# ==============================================================================
class_name MonkeyEntity
extends PassiveEntity

# --- TACTICAL AUDIO COOLDOWN TIMERS (SRP / OCP Compliant) ---
const COOLDOWN_CHAT_MIN_SEC: float = 15.0
const COOLDOWN_CHAT_MAX_SEC: float = 25.0

# Start with a random initial offset so they don't all yell at spawn
var _chat_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Monkeys spawn with 3 Hearts of health (6 HP) and terrestrial boundaries
	super(spawn_pos, 6)
	entity_habitat = 0 # Terrestrial
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
	
	# Inject the specialized Monkey acrobatic AI strategy dynamically on ready
	if is_instance_valid(ai_component):
		ai_component.active_behavior = MonkeyAIBehavior.new()


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

func _get_entity_name_key() -> String:
	return "NPC_NAME_MONKEY"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Friendly/Passive Green


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
	AudioService.play_sfx_static("monkey_chatter", global_position, 55.0)


## Visual Backflip: Propels vertically and rotates 360 degrees on X-axis (Pitch roll)
## Note: Invoked via reflective calls by the MonkeyAIBehavior strategy
func _play_backflip_effect() -> void:
	velocity.y = JUMP_VELOCITY * 1.3
	
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
	if domain_entity.is_dead:
		return
		
	# Process ambient chatter timer locally in the presenter to decouple audio
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5: # TASK_PANIC = 5
		is_panicking = true
		
	if not is_panicking:
		_chat_timer -= delta
		if _chat_timer <= 0.0:
			_chat_timer = randf_range(COOLDOWN_CHAT_MIN_SEC, COOLDOWN_CHAT_MAX_SEC)
			_play_monkey_chatter()
