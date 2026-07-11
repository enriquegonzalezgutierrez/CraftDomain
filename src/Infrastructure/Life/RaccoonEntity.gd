# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Wildlife)
# Class: RaccoonEntity
# Description: Physical character controller for the forest Raccoon.
#              Delegates all daytime sleeps, nighttime village barrel stalking,
#              and scratching timers to the decoupled RaccoonAIBehavior strategy,
#              managing wood-chip particle feedback and scratch audio cues.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, and claw scratch visual wood particles.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
# ==============================================================================
class_name RaccoonEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Raccoons spawn with 2 Hearts of health (4 HP) and terrestrial boundaries
	super(spawn_pos, 4)
	entity_habitat = 0 # Terrestrial
	name = "Entity_RACCOON"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# TANGENT SHIELD FIX: Strip materials of tangent-requiring shaders to avoid C++ warnings
	var model_node := get_node_or_null("Visuals/BodyBobJoint/raccoon") as Node3D
	if is_instance_valid(model_node):
		_register_glb_materials(model_node)
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# Inject the specialized Raccoon cleptomaniac AI strategy dynamically on ready
	if is_instance_valid(ai_component):
		ai_component.active_behavior = RaccoonAIBehavior.new()


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
	return "NPC_NAME_RACCOON"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Friendly/Passive Green


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Fried Chicken (acting as soft feline meat proxy)
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


# ==============================================================================
# TACTICAL CLAW SCRATCHING & BARREL BREAKOUT EFFECTS
# ==============================================================================

## Visual Scratching: Directs gaze towards targeted barrel, triggers scratch sound and wood chips
## Note: Invoked via reflective calls by the RaccoonAIBehavior strategy
func _play_scratching_effect(target_node: Node3D) -> void:
	if not is_instance_valid(target_node):
		return
		
	var look_dir := (target_node.global_position - global_position).normalized()
	look_dir.y = 0.0
	if is_instance_valid(ai_component):
		ai_component.wander_direction = look_dir
		
	# Gesticulate scratch swipes and throttle wood chip spawn rate (10Hz)
	var frame_stamp := Engine.get_physics_frames()
	if frame_stamp % 10 == 0:
		_spawn_claw_wood_particles(target_node.global_position)
		AudioService.play_sfx_static("footstep_wood", global_position)


## Spawns tiny unshaded wood shavings that drift down via gravity (Compile-Free CPU)
func _spawn_claw_wood_particles(target_pos: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 4
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.40
	
	var direction_vec := (global_position - target_pos).normalized()
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.1
	particles.direction = direction_vec
	particles.spread = 30.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 2.5
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.03, 0.03)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.30, 0.15) # Wood Oak Brown
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	
	# Native leak-free automatic cleanup on complete emission (Milestone 7)
	particles.finished.connect(particles.queue_free)
	
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(particles)
		particles.global_position = global_position.lerp(target_pos, 0.6) + Vector3(0.0, 0.2, 0.0)
		particles.emitting = true
