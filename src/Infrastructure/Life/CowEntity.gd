# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Wildlife)
# Class: CowEntity
# Description: Physical character controller for the passive Clay Cow.
#              Delegates its visual clay-voxel representation and physical 
#              translations completely to the Godot Editor (.tscn).
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   passive movement, panic bounces, local audio vocal timers, and signal-bound loot drops.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
# ==============================================================================
class_name CowEntity
extends PassiveEntity

# --- TACTICAL AUDIO COOLDOWN TIMERS (SRP / OCP Compliant) ---
const COOLDOWN_MOO_MIN_SEC: float = 20.0
const COOLDOWN_MOO_MAX_SEC: float = 35.0

# Start with a random initial offset on spawn so they don't sync up
var _moo_timer: float = randf_range(5.0, 20.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 6)
	entity_habitat = 0 # Terrestrial
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
	return "NPC_NAME_COW"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Friendly/Passive Green


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Fertile Soil (ID 2) and 1x raw cow meat (Fried Chicken proxy ID 16)
	inv.add_item(2, 1)
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


# ==============================================================================
# TACTICAL AUDIO PRESENTATION
# ==============================================================================

## Visual/Audio Cow Vocalization: Plays the designated 3D spatial low-pitch moo
func _play_cow_vocal() -> void:
	AudioService.play_sfx_static("cow_moo", global_position, 50.0)


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	# Process ambient moo timer locally in the presenter to decouple audio
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5: # TASK_PANIC = 5
		is_panicking = true
		
	if not is_panicking:
		_moo_timer -= delta
		if _moo_timer <= 0.0:
			_moo_timer = randf_range(COOLDOWN_MOO_MIN_SEC, COOLDOWN_MOO_MAX_SEC)
			_play_cow_vocal()
