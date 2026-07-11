# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Hostiles)
# Class: SharkEntity
# Description: Physical character controller for the hostile Great White Shark.
#              Delegates all coordinate scent tracking, player chase paths, 
#              and surface leap attacks to the decoupled SharkAIBehavior strategy.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, local audio vocal timers, and procedural 
#   mesh tail-wag animations.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key, red color,
#   and overriding `_physics_tick()` to avoid parent `super()` compilation errors.
# ==============================================================================
class_name SharkEntity
extends PassiveEntity

# Sibling node references
var player: CharacterBody3D

# Dynamic cached reference to visual model
var _model_node: Node3D

# Visual model baseline Y-coordinate yaw rotation configured in the editor
var _model_base_y: float = 0.0

# --- TACTICAL AUDIO COOLDOWN TIMERS (SRP / OCP Compliant) ---
const COOLDOWN_ATTACK_MIN_SEC: float = 18.0
const COOLDOWN_ATTACK_MAX_SEC: float = 35.0

# Start with a random initial offset on spawn so they don't sync up
var _attack_sound_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Sharks spawn with 4 Hearts of health (8 HP) and aquatic boundaries
	super(spawn_pos, 8)
	entity_habitat = 2 # Aquatic (Water only)
	name = "Entity_SHARK"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the hostile group for O(1) targeting sweeps
	add_to_group("hostiles")
	if is_in_group("passives"):
		remove_from_group("passives") # Unregister from peaceful list (OCP/LSP)
	
	# Cache component references pre-configured in the scene
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/shark") as Node3D
	
	# TANGENT SHIELD FIX: Strip materials of tangent-requiring shaders to avoid C++ warnings
	if is_instance_valid(_model_node):
		_register_glb_materials(_model_node)
		_model_base_y = _model_node.rotation.y
	
	_locate_player()
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# Inject the specialized Shark aquatic predator AI strategy dynamically on ready
	if is_instance_valid(ai_component):
		ai_component.active_behavior = SharkAIBehavior.new()


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
	return "NPC_NAME_SHARK"


func _get_nameplate_color() -> Color:
	return Color(0.95, 0.15, 0.15) # Hostile Red (LSP Compliant)


## SOLID RESOLUTION (LSP/OCP): Overrides the custom virtual physics hook.
## Completely avoids calling `super(delta)` inside engine virtual callbacks.
func _physics_tick(delta: float) -> void:
	_process_procedural_swimming(delta)


func _has_ui_decorations() -> bool:
	return true


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _on_domain_entity_took_damage(_amount: int) -> void:
	pass # Hostiles do not panic when hit


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(7, 1)


# ==============================================================================
# TACTICAL AUDIO PRESENTATION
# ==============================================================================

## Visual/Audio Shark Vocalization: Plays the designated subaquatic growl
func _play_shark_vocal() -> void:
	AudioService.play_sfx_static("shark_attack", global_position)


## Tactical Action bite: Inflicts heavy damage (1.5 Hearts / 3 HP) and applies knockback
func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(dir.x * 6.5, 2.5, dir.z * 6.5)
		_play_shark_vocal()
		if player.has_method("take_damage"):
			player.call("take_damage", 3, knockback)


# ==============================================================================
# PROCEDURAL TAIL-WAG OSCILLATION
# ==============================================================================

func _process_procedural_swimming(delta: float) -> void:
	if is_instance_valid(_model_node):
		var anim_time: float = Time.get_ticks_msec() / 1000.0
		var flat_velocity := Vector2(velocity.x, velocity.z)
		var is_moving := flat_velocity.length_squared() > 0.1
		
		if is_moving:
			var swim_speed := flat_velocity.length() * 2.5
			_model_node.rotation.y = _model_base_y + sin(anim_time * swim_speed) * 0.22
			_model_node.rotation.z = cos(anim_time * swim_speed * 0.5) * 0.08 
		else:
			_model_node.rotation.y = lerp_angle(_model_node.rotation.y, _model_base_y, delta * 5.0)
			_model_node.rotation.z = sin(anim_time * 1.5) * 0.03


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5: # TASK_PANIC = 5
		is_panicking = true
		
	if not is_panicking:
		_attack_sound_timer -= delta
		if _attack_sound_timer <= 0.0:
			_attack_sound_timer = randf_range(COOLDOWN_ATTACK_MIN_SEC, COOLDOWN_ATTACK_MAX_SEC)
			_play_shark_vocal()
