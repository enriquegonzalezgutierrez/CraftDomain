# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Wildlife)
# Class: GrowlitheEntity
# Description: Physical character controller for the loyal canine Growlithe.
#              Delegates all magma sniping, territorial heat seeking, and
#              fiery barks to the decoupled CanineAIBehavior strategy, managing
#              visual incandescent flame embers.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, snout fire bark visual particles, and local audio timers.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
# ==============================================================================
class_name GrowlitheEntity
extends PassiveEntity

# --- TACTICAL AUDIO COOLDOWN TIMERS (SRP / OCP Compliant) ---
const COOLDOWN_BARK_MIN_SEC: float = 15.0
const COOLDOWN_BARK_MAX_SEC: float = 30.0

# Start with a random initial offset on spawn so they don't sync up
var _bark_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Growlithes spawn with 3 Hearts of health (6 HP) and terrestrial boundaries
	super(spawn_pos, 6)
	entity_habitat = 0 # Terrestrial
	name = "Entity_GROWLITHE"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target scans
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# TANGENT SHIELD FIX: Strip materials of tangent-requiring shaders to avoid C++ warnings
	var model_node := get_node_or_null("Visuals/BodyBobJoint/growlithe") as Node3D
	if is_instance_valid(model_node):
		_register_glb_materials(model_node)
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# Inject the specialized Growlithe canine AI strategy dynamically on ready
	if is_instance_valid(ai_component):
		ai_component.active_behavior = CanineAIBehavior.new()


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
	return "NPC_NAME_GROWLITHE"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Friendly/Passive Green


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Fried Chicken (acting as raw fire-meat proxy)
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


# ==============================================================================
# TACTICAL FLAME BARKING & MAGMA SNIFFING PRESENTATION
# ==============================================================================

## Visual Flame Bark: Plays alert bark audio and spawns glowing fire embers
## Note: Invoked via reflective calls by the CanineAIBehavior strategy and locally
func _play_flame_bark() -> void:
	# Playful vertical hop
	velocity.y = 2.8
	AudioService.play_sfx_static("growlithe_bark", global_position, 45.0)
	_spawn_flame_bark_particles()


## Spawns tiny unshaded orange fire boxes that drift upwards (Compile-Free CPU)
func _spawn_flame_bark_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 10
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.55
	
	var forward_dir := Vector3.FORWARD
	if is_instance_valid(ai_component):
		forward_dir = ai_component.wander_direction
		
	# Tilt trajectory vector slightly upwards
	forward_dir = (forward_dir + Vector3(0.0, 0.4, 0.0)).normalized()
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.10
	particles.direction = forward_dir
	particles.spread = 20.0
	particles.initial_velocity_min = 2.5
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0.0, 2.5, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.0) # Bright orange
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.0)
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	
	# Native leak-free automatic cleanup on complete emission (Milestone 7)
	particles.finished.connect(particles.queue_free)
	
	add_child(particles)
	particles.position = Vector3(0.0, _collision_height - 0.2, -0.15)
	particles.emitting = true


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	# Process ambient bark timer locally in the presenter to decouple audio
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5: # TASK_PANIC = 5
		is_panicking = true
		
	if not is_panicking:
		_bark_timer -= delta
		if _bark_timer <= 0.0:
			_bark_timer = randf_range(COOLDOWN_BARK_MIN_SEC, COOLDOWN_BARK_MAX_SEC)
			_play_flame_bark()
