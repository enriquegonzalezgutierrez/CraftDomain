# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Wildlife)
# Class: ParrotEntity
# Description: Physical character controller for the flying Tropical Parrot.
#              Delegates all flight and perching decisions to the AvianAIBehavior 
#              strategy, managing wing flap sways.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, coordinate-facing rotations, wing flap sways, and local audio 
#   chatter timers, keeping the shared Domain flight strategy pristine.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
# ==============================================================================
class_name ParrotEntity
extends PassiveEntity

# Animation and visual reference trackers
var _animation_time: float = 0.0
var _model_node: Node3D

# Visual model baseline Y-coordinate (Y-axis origin when perched)
const MODEL_BASE_Y: float = 0.0

# --- TACTICAL AUDIO COOLDOWN TIMERS (SRP / OCP Compliant) ---
const COOLDOWN_CHAT_MIN_SEC: float = 15.0
const COOLDOWN_CHAT_MAX_SEC: float = 25.0

# Start with a random initial offset on spawn so they don't sync up
var _chat_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Parrots spawn with 1 Heart of health (2 HP, fragile) and custom flight/air boundaries
	super(spawn_pos, 2)
	entity_habitat = 0 # Terrestrial (perches on leaves)
	name = "Entity_PARROT"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Cache the 3D model child node to apply flight sways in real-time
	_model_node = get_node_or_null("Visuals/BodyBobJoint/parrot") as Node3D
	
	# TANGENT SHIELD FIX: Strip materials of tangent-requiring shaders to avoid C++ warnings
	if is_instance_valid(_model_node):
		_register_glb_materials(_model_node)
	
	# Fetch nameplate configurations from inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# Inject the specialized Avian flight/perch AI strategy dynamically on ready
	if is_instance_valid(ai_component):
		ai_component.active_behavior = AvianAIBehavior.new()


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
	return "NPC_NAME_PARROT"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Friendly/Passive Green


func _is_avian() -> bool:
	return true


func _can_fly() -> bool:
	return true # Bypasses gravity void-clamping inside base class PassiveEntity


func _can_socialize() -> bool:
	return true


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Fried Chicken (acting as soft avian meat proxy)
	inv.add_item(16, 1)


# ==============================================================================
# TACTICAL AUDIO & FX PRESENTATION
# ==============================================================================

## Visual/Audio Avian Chatter: Plays the designated long 3D spatial squawk
func _play_avian_chatter() -> void:
	AudioService.play_sfx_static("parrot_squawk", global_position, 60.0)


# ==============================================================================
# PROCEDURAL FLIGHT ANIMATIONS & ALTIMETRICAL ROTATIONS
# ==============================================================================

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
			_play_avian_chatter()
			
	# ==========================================================================
	# VISUAL SKELETAL SWAYS
	# ==========================================================================
	if is_instance_valid(_model_node):
		# Read flight state from metadata safely (DIP)
		var flight_state := 0 # Default STATE_SOARING
		if has_meta(AvianAIBehavior.META_STATE):
			flight_state = get_meta(AvianAIBehavior.META_STATE) as int
			
		if flight_state == 2: # STATE_PERCHED (Resting flat on top of leaves)
			_model_node.position.y = MODEL_BASE_Y
			_model_node.rotation.z = 0.0
			_model_node.rotation.x = 0.0
		else:
			# FLIGHT FLAPPING ACTIVE STATE
			_animation_time += delta
			
			var flat_velocity := Vector2(velocity.x, velocity.z)
			var is_moving := flat_velocity.length_squared() > 0.1
			
			# Smooth thermal hover bobbing
			var hover_bob := sin(_animation_time * 3.5) * 0.22
			
			var is_showcase := false
			var current_node := get_parent()
			while current_node != null:
				if current_node is SubViewport and current_node.name != "root":
					is_showcase = true
					break
				current_node = current_node.get_parent()
				
			if is_showcase:
				_model_node.position.y = MODEL_BASE_Y # Sinks to floor inside showroom
			else:
				_model_node.position.y = MODEL_BASE_Y + hover_bob
			
			if is_moving:
				# High-frequency Z-axis rotation roll to simulate flapping wings
				_model_node.rotation.z = sin(_animation_time * 16.0) * 0.22
				_model_node.rotation.x = deg_to_rad(12.0) # Pitch forward
			else:
				# Slow resting glide sways
				_model_node.rotation.z = sin(_animation_time * 1.8) * 0.04
				_model_node.rotation.x = 0.0
				
		# ======================================================================
		# UNIVERSAL DYNAMIC NAMEPLATE POSITIONER (OCP / SOLID COMPLIANT)
		# ======================================================================
		if is_instance_valid(_nameplate):
			var relative_offset := _model_node.position.y - MODEL_BASE_Y
			_nameplate.position.y = _collision_height + 0.35 + relative_offset
