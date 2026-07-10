# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: OctopusEntity
# Description: Physical character controller for the aquatic Octopus.
#              Delegates all timed jet propulsions, marine gliding, and 
#              defensive ink-spraying to the decoupled OctopusAIBehavior strategy,
#              managing visual dark ink particles and bubble audio cues.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, and underwater ink spray visual particles.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, relying on its parent physics process and signals.
# - Dependency Inversion Principle (DIP): Injects the OctopusAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/OctopusEntity.gd
# ==============================================================================
class_name OctopusEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Octopus spawns with 3 Hearts of health (6 HP)
	super(spawn_pos, 6)
	name = "Entity_OCTOPUS"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# TANGENT SHIELD FIX: Strip materials of tangent-requiring shaders to avoid C++ warnings
	var model_node := get_node_or_null("Visuals/BodyBobJoint/octopus") as Node3D
	if is_instance_valid(model_node):
		_register_glb_materials(model_node)
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# Programmatically instantiates NPCAIComponent if missing from old scenes
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	if not is_instance_valid(ai_component):
		ai_component = NPCAIComponent.new()
		add_child(ai_component)
		
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Octopus aquatic pulsing AI strategy dynamically on ready,
	# completely overriding the default generic wildlife behavior assigned by Bootstrap.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = OctopusAIBehavior.new()


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
	return 2 # Equivalent to MobRegistry.Habitat.AQUATIC


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Sand Block (acting as granular sediment)
	inv.add_item(7, 1)


func _is_avian() -> bool:
	return true # Activates slight procedural swimming tilts


func _can_socialize() -> bool:
	return true


# ==============================================================================
# TACTICAL PRESENTATION & AQUATIC DEFENSIVE INK SPRAY
# ==============================================================================

## Visual Ink Spray: Spawns thick unshaded charcoal cloud particles to blind threats
## Note: Invoked via reflective calls by the OctopusAIBehavior strategy
func _play_ink_spray() -> void:
	_spawn_black_ink_shroud()


## Instantiates dense unshaded black box meshes that drift slowly underwater (Compile-Free CPU)
func _spawn_black_ink_shroud() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 18
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 1.2 # Shroud lingers in currents
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.3
	particles.direction = Vector3(0.0, 0.2, 0.0)
	particles.spread = 180.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.5
	particles.gravity = Vector3(0.0, -0.4, 0.0) # Slow sink in dense water
	
	# Charcoal-black box particles representing the ink mass
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.18, 0.18)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.07) # Thick deep abisal Black
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	
	# Native leak-free automatic cleanup on complete emission (Milestone 7)
	particles.finished.connect(particles.queue_free)
	
	# Add to world parent node to prevent particles moving with the octopus
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(particles)
		particles.global_position = global_position + Vector3(0.0, 0.2, 0.0)
		particles.emitting = true
