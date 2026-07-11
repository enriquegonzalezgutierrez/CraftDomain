# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Wildlife)
# Class: FoxEntity
# Description: Physical character controller for the forest predator Fox.
#              Delegates all leaves scans, crawling crouches, and pounce leaps
#              to the decoupled FoxAIBehavior strategy, managing visual flattening
#              offsets, local audio vocal timers, and strike damage upon landings.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, local audio vocal timers, and dynamic crouching mesh scales.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
# ==============================================================================
class_name FoxEntity
extends PassiveEntity

# --- TACTICAL AUDIO COOLDOWN TIMERS (SRP / OCP Compliant) ---
# Foxes screech occasionally to communicate in the mossy valleys of the forest
const COOLDOWN_CHAT_MIN_SEC: float = 20.0
const COOLDOWN_CHAT_MAX_SEC: float = 35.0

# Start with a random initial offset on spawn so they don't sync up
var _chat_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Foxes spawn with 2 Hearts of health (4 HP) and terrestrial boundaries
	super(spawn_pos, 4)
	entity_habitat = 0 # Terrestrial
	name = "Entity_FOX"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target scans
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
	
	# Inject the specialized Fox predator AI strategy dynamically on ready
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

func _get_entity_name_key() -> String:
	return "NPC_NAME_FOX"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Friendly/Passive Green


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
		
	# Plays the fox hunt screech sound with a custom 35.0 meters spatial distance
	AudioService.play_sfx_static("fox_screech", global_position, 35.0)
	
	# Execute damage strike upon landing
	if target.has_method("take_damage"):
		var direction_vec: Vector3 = (target.global_position - global_position).normalized()
		var pounce_knockback: Vector3 = direction_vec * 4.2 + Vector3(0.0, 1.8, 0.0)
		target.call("take_damage", 2, pounce_knockback, self) # Inflicts 2 HP (1 Heart)


## Visual/Audio Fox Vocalization: Plays the designated ambient spatial screech
func _play_fox_vocal() -> void:
	AudioService.play_sfx_static("fox_screech", global_position, 45.0)


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	# Process ambient screech timer locally in the presenter to decouple audio
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5: # TASK_PANIC = 5
		is_panicking = true
		
	if not is_panicking:
		_chat_timer -= delta
		if _chat_timer <= 0.0:
			_chat_timer = randf_range(COOLDOWN_CHAT_MIN_SEC, COOLDOWN_CHAT_MAX_SEC)
			_play_fox_vocal()
